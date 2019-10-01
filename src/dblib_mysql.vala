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
       * The encoding which should be used for the database connection.
       */
      private string? encoding;

      /**
       * The port which should be used to connect to the database.
       */
      private uint port = 0;

      /**
       * This constructor will create a new database connection to a MySQL database.
       * @param dsn A DataSourceName object containing the informations which will be passed to the MySQL library.
       * @param user A user which should be used to connect to the database.
       * @param password A password which should be used to connect to the database.
       * @param encoding A encoding which should be used for the database connection.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      public Connection( DataSourceName dsn, string? user, string? password, string? encoding ) throws DBLib.DBError.CONNECTION_ERROR
      {
        this.dsn = dsn;
        this.user = user;
        this.password = password;
        this.encoding = encoding;

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

        if ( this.encoding != null )
        {
          this.dbh.set_character_set( (!)this.encoding );
        }
      }

      /**
       * @see DBLib.Connection. execute_query
       */
      public override void execute_query( string code ) throws DBLib.DBError.STATEMENT_ERROR
      {
        if ( this.dbh.real_query( code, code.length ) != 0 )
        {
          uint err_no = this.dbh.errno( );
          string err_msg = this.dbh.error( );

          /* Check Connection */
          if ( this.dbh.ping( ) != 0 )
          {
            /* No connection */
            this.connect( );
            if ( this.dbh.real_query( code, code.length ) != 0 )
            {
              throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database after retry! MySQL Error %u: %s", code, this.dbh.errno( ), this.dbh.error( ) );
            }
          }
          else
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database! MySQL Error %u: %s", code, err_no, err_msg );
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
       * This method will generate the final statement code using the given code and specified parameters.
       * It will replace question marks in the statement code and replace them with the escaped params.
       * @return The final statement code.
       * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters.
       */
      public string get_final_code( DBLib.Statement statment ) throws DBLib.DBError.STATEMENT_ERROR
      {
        char c;
        string code = statment.to_sql( );
        int code_length = code.length;
        int next_parameter = 0;
        StringBuilder final_code = new StringBuilder.sized( code_length );

        string[] params = statment.get_binds( );
        for ( int i = 0; i < code_length; i ++ )
        {
          c = code[ i ];

          if ( c == '?' )
          {
            /* Get the next parameter and escape it. */
            if ( next_parameter >= params.length )
            {
              /* There is no more parameter! */
              DMLogger.log.error( 0, false, "Error while generating final statement code for statement ${1}! Expected ${1} parameters but only ${3} were sepcified! ${4}", code, ( next_parameter + 1 ).to_string( ), params.length.to_string( ), this.get_params_string( params )
              );
              for ( int j = 0; j < params.length; j ++ )
              {
                DMLogger.log.error( 0, false, "Parameter ${1}: ${2}", ( j + 1 ).to_string( ), params[ j ] ?? "NULL" );
              }
              throw new DBLib.DBError.STATEMENT_ERROR( "Error while generating final statement code for statement %s! Expected %d parameters but only %d were sepcified! %s", code, next_parameter + 1, params.length, this.get_params_string( params ) );
            }

            final_code.append( this.escape( params[ next_parameter ] ) );
            next_parameter ++;
          }
          else
          {
            final_code.append_c( c );
          }
        }
        return final_code.str;
      }

    /**
     * This method convert the params array into a readable log string.
     * @return The params as a string for a log message.
     */
    public string get_params_string( string[] params )
    {
      string param_string = "";
      for( int i = 0; i < params.length; i ++ )
      {
        param_string += "\nParams %d: %s".printf( i, params[ i ] );
      }
      return param_string;
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
        string final_code;
        string[] binds = statment.get_binds( );
        if ( binds.length > 0 )
        {
          final_code = this.get_final_code( statment );
        }
        else
        {
          final_code = statment.to_sql( );
        }

        this.execute_query( final_code );
        if ( callback != null )
        {
          try
          {
            char ** data = null;
            ulong[] array_lengths = null;
            DBLib.Result result = this.get_result( false );
            while ( ( data = result.fetchrow_binary( out array_lengths ) ) != null )
            {
              callback( data, array_lengths );
            }
          }
          catch( Error e )
          {
            throw new DBLib.DBError.STATEMENT_ERROR( e.message );
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
      /**
       * The MySQL connection which is used to fetch the result.
       */
      private DBLib.MySQL.Connection mysql_conn;

      /**
       * The result object which was fetched from MySQL.
       */
      private Mysql.Result? mysql_result;

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

        this.mysql_conn = (DBLib.MySQL.Connection)conn;

        this.mysql_result = null;
        if ( this.server_side_result )
        {
          this.mysql_result = this.mysql_conn.dbh.use_result( );
        }
        else
        {
          this.mysql_result = this.mysql_conn.dbh.store_result( );
        }

        /*
         * When the acquired result is null there was maybe an error...
         */
        if ( this.mysql_result == null && this.mysql_conn.dbh.errno( ) != 0 )
        {
          throw new DBLib.DBError.RESULT_ERROR( "Error while fetching result from database server! %u: %s", this.mysql_conn.dbh.errno( ), this.mysql_conn.dbh.error( ) );
        }
      }

      /*
       * @see DBLib.Result.fetchrow_hash
       */
      public override HashTable<string?,string?>? fetchrow_hash( )
      {
        string[]? row_data = this.mysql_result.fetch_row( );
        if ( row_data == null )
        {
          return null;
        }

        if ( this.mysql_fields == null )
        {
          this.mysql_fields = this.mysql_result.fetch_fields( );
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
        return this.mysql_result.fetch_row( );
      }


      /**
       * @see DBLib.Result.fetchrow_binary
       */
      public override char** fetchrow_binary( out ulong[] array_length )
      {
        char** data = this.mysql_result.fetch_row( );
        if ( data == null )
        {
          return null;
        }
        array_length = this.mysql_result.fetch_lengths( );
        return data;
      }
    }
  }
}
