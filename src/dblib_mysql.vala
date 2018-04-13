/*
 * This file contains the MySQL driver of the DBLib.
 * (c) 2014 by DocuMatrix GmbH
 */

namespace DBLib
{
  namespace MySQL
  {
    public class Connection : DBLib.Connection
    {
      /**
       * The MySQL database handle.
       */
      public Mysql.Database dbh;

      /**
       * The user which should be used to connect to the database.
       */
      private string? user;

      /**
       * The password which should be used to connect to the database.
       */
      private string? password;

      /**
       * The port which should be used to connect to the database.
       */
      private uint port = 0;

      /**
       * This constructor will create a new database connection to a MySQL database.
       * @param dsn A DataSourceName object containing the informations which will be passed to the MySQL library.
       * @param user A user which should be used to connect to the database.
       * @param password A password which should be used to connect to the database.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      public Connection( DataSourceName dsn, string? user, string? password ) throws DBLib.DBError.CONNECTION_ERROR
      {
        this.dsn = dsn;
        this.user = user;
        this.password = password;

        this.dbh = new Mysql.Database( );

        if ( dsn[ "port" ] != null )
        {
          this.port = (uint)uint64.parse( dsn[ "port" ] );
        }
        this.connect( );
      }

      /**
       * This method can be used to connect to the database.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      private void connect( ) throws DBLib.DBError.CONNECTION_ERROR
      {
        if ( !this.dbh.real_connect( this.dsn[ "host" ], this.user, this.password, this.dsn[ "database" ], this.port, this.dsn[ "unix_socket" ] ) )
        {
          throw new DBLib.DBError.CONNECTION_ERROR( "Could not connect to MySQL database! %u: %s", this.dbh.errno( ), this.dbh.error( ) );
        }
      }

      /**
       * @see DBLib.Connection. execute_query
       */
      public override void execute_query( string code ) throws DBLib.DBError.STATEMENT_ERROR
      {
        if ( this.dbh.real_query( code, code.length ) != 0 )
        {
          /* Check Connection */
          if ( this.dbh.ping( ) != 0 )
          {
            /* No connection */
            this.connect( );
            if ( this.dbh.real_query( code, code.length ) != 0 )
            {
              throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database! %u: %s", code, this.dbh.errno( ), this.dbh.error( ) );
            }
          }
          else
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database! %u: %s", code, this.dbh.errno( ), this.dbh.error( ) );
          }
        }
      }

      /**
       * @see DBLib.Connection.get_result
       */
      public override DBLib.Result get_result( bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        return new DBLib.MySQL.Result( this, server_side_result );
      }

      /**
       * @see DBLib.Connection.get_insert_id
       */
      public override uint64 get_insert_id( )
      {
        return this.dbh.insert_id( );
      }

      public override string column_definition_to_sql( ColumnDefinition column )
      {
        string column_sql = "`%s` %s".printf( column.name, column.data_type.to_string( ) );
        if ( column.size != 0 )
        {
          column_sql = column_sql.concat( "(%u)".printf( column.size ) );
        }
        if ( column.is_unsigned )
        {
          column_sql = column_sql.concat( " UNSIGNED" );
        }
        if ( column.is_nullable )
        {
          column_sql = column_sql.concat( " NULL" );
        }
        else
        {
          column_sql = column_sql.concat( " NOT NULL" );
        }

        switch ( column.default_value_type )
        {
          case DefaultValueType.NO_DEFAULT:
            break;
          case DefaultValueType.NULL:
            column_sql = column_sql.concat( " DEFAULT NULL" );
            break;
          case DefaultValueType.CURRENT_TIMESTAMP:
            column_sql = column_sql.concat( " DEFAULT CURRENT_TIMESTAMP" );
            break;
          case DefaultValueType.AUTO_INCREMENT:
            column_sql = column_sql.concat( " AUTO_INCREMENT" );
            break;
          case DefaultValueType.CUSTOM:
            column_sql = column_sql.concat( " DEFAULT '%s'".printf( column.default_value ) );
            break;
        }

        return column_sql;
      }

      /**
       * @see DBLib.Connection.quote
       */
      public override string quote( string val )
      {
        return "`".concat( val, "`" );
      }

      /**
       * This method will replace the question marks in the statement code by the given parameters and will execute
       * the statement.
       * @return The executed statement.
       * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters or while executing the statement.
       * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the resultset.
       */
      public override DBLib.Statement execute_binary( DBLib.Statement statment, SelectStatementBinaryCallback? callback = null ) throws DBLib.DBError.STATEMENT_ERROR, DBLib.DBError.RESULT_ERROR
      {
        MySQL.Result result = new Result( this, false );
        result.init( statment );
        statment.result = result;

        if ( callback != null )
        {
          void*[] data = null;
          ulong[] data_length;
          while( statment.result.fetchrow_binary( out data_length ) != null )
          {
            callback( data, data_length );
          }
        }
        return statment;
      }

      public string escape( string? val )
      {
        if ( val == null )
        {
          return "NULL";
        }
        else
        {
          string escaped = string.nfill( val.length * 2 + 1, ' ' );
          ulong res_len = this.dbh.real_escape_string( escaped, val, val.length );
          return "\"" + escaped + "\"";
        }
      }
    }

    /**
     * This class is a implementation for the abstract class DBLib.Result
     */
    public class Result : DBLib.Result
    {
      private Mysql.Statment? stmt;

      private ulong[] data_length;

      private char[] test;

      private Mysql.Bind[] mysql_binds;

      /**
       * The result object which was fetched from MySQL.
       */
      private Mysql.Result? mysql_metadata;

      /**
       * This array may contain the field informations for the resultset.
       * It will be initialized by fetchrow_hash the first time the method is called.
       */
      private Mysql.Field[] mysql_fields;

      /**
       * @see DBLib.Result
       * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the result from MySQL.
       */
      public Result( DBLib.MySQL.Connection conn, bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        base( conn, server_side_result );
      }

      public void init( DBLib.Statement statment )
      {
        string final_code = statment.to_sql( );
        void*[] binds = statment.get_binds( );
        Type[] types = statment.get_types( );
        int result;
        this.stmt = ( (DBLib.MySQL.Connection)this.conn ).dbh.create_statment( );
        this.stmt.prepare( final_code, final_code.length );
        {
          Mysql.Bind[] mysql_binds = new Mysql.Bind[ types.length ];
          for ( int i = 0; i < types.length; i ++ )
          {
            if ( types[ i ] == typeof( string ) )
            {
              mysql_binds[ i ].buffer_type = Mysql.FieldType.STRING;
              mysql_binds[ i ].buffer_length = ( (string)binds[ i ] ).length;
            }
            else if ( types[ i ] == typeof( uint8[] ) )
            {
              mysql_binds[ i ].buffer_type = Mysql.FieldType.BLOB;
              mysql_binds[ i ].buffer_length = ( (uint8[])binds[ i ] ).length;
            }
            else
            {
              throw new DBLib.DBError.STATEMENT_ERROR( "Unimplemente Type %s", types[ i ].name( ) );
            }

            mysql_binds[ i ].buffer = binds[ i ];
          }
          if ( this.stmt.bind_param( mysql_binds ) != 0 )
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Could not Bind Params %s", this.stmt.error( ) );
          }
        }

        if ( this.stmt.execute( ) != 0 )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Could not Execute %s", this.stmt.error( ) );
        }
        this.mysql_metadata = this.stmt.result_metadata( );
        if ( this.mysql_metadata == null )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Could not Read Metadata of Statment %s", this.stmt.error( ) );
        }
        else
        {
          this.mysql_fields = this.mysql_metadata.fetch_fields( );
          this.mysql_binds = new Mysql.Bind[ this.mysql_fields.length ];
          this.data_length = new ulong[ this.mysql_fields.length ];

          for( int i = 0; i < this.mysql_fields.length; i ++ )
          {
            uint8[] data = new uint8[ this.mysql_fields[ i ].length + 1 ];
            this.mysql_binds[ i ].buffer_type = this.mysql_fields[ i ].type;
            this.mysql_binds[ i ].buffer = &data;
            this.mysql_binds[ i ].buffer_length = this.mysql_fields[ i ].length;
            this.data_length[ i ] = this.mysql_fields[ i ].length;
          }
          if ( this.stmt.bind_result( mysql_binds ) != 0 )
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Could not Bind Result %s", this.stmt.error( ) );
          }
          if ( this.stmt.store_result( ) != 0 )
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Could not Store Result %s", this.stmt.error( ) );
          }
        }
      }

      /*
       * @see DBLib.Result.fetchrow_hash
       */
      public override HashTable<string?,string?>? fetchrow_hash( )
      {
        string[]? row_data = this.fetch_row( );
        if ( row_data == null )
        {
          return null;
        }

        HashTable<string?,string?> row = new HashTable<string?,string?>( str_hash, str_equal );
        for ( int i = 0; i < this.mysql_fields.length; i ++ )
        {
          row.insert( this.mysql_fields[ i ].name, row_data[ i ] );
        }
        return row;
      }

      /**
       * @see DBLib.Result.fetchrow_array
       */
      public override string[]? fetchrow_array( )
      {
        return this.fetch_row( );
      }

      public string[]? fetch_row( )
      {
        ulong[] array_length;
        void*[] array = this.fetchrow_binary( out array_length );
        return (string[])array;
      }

      /**
       * @see DBLib.Result.fetchrow_binary
       */
      public override void*[] fetchrow_binary( out ulong[] array_length )
      {
        if ( this.stmt.fetch( ) != 0 )
        {
          return null;
        }
        void*[] data = new void*[ this.data_length.length ];
        array_length = new ulong[ this.data_length.length ];
        for( int i = 0; i < this.data_length.length; i ++ )
        {
          data[ i ] = this.mysql_binds[ i ].buffer;
          array_length[ i ] = this.mysql_binds[ i ].buffer_length;
        }
        return data;
      }
    }
  }
}
