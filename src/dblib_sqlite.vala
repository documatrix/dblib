/*
 * This file contains the MySQL driver of the DBLib.
 * (c) 2014 by DocuMatrix GmbH
 */

namespace DBLib
{
  namespace SQLite
  {
    public class Connection : DBLib.Connection
    {
      /**
       * This is the SQLite database.
       */
      public Sqlite.Database database;

      public Sqlite.Statement stmt;

      /**
       * This constructor will create a new database connection to a MySQL database.
       * @param dsn A DataSourceName object containing the informations which will be passed to the MySQL library.
       * @param user A user which should be used to connect to the database.
       * @param password A password which should be used to connect to the database.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      public Connection( DataSourceName dsn ) throws DBLib.DBError.CONNECTION_ERROR
      {
        this.dsn = dsn;
        this.connect( );
      }

      /**
       * This method can be used to connect to the database.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      private void connect( ) throws DBLib.DBError.CONNECTION_ERROR
      {
        string db_file = dsn[ "db_file" ];
        int rc = Sqlite.Database.open( db_file, out this.database );
        if ( rc != Sqlite.OK )
        {
          throw new DBError.CONNECTION_ERROR( "Could not open database %s! %s", db_file, this.get_sqlite_error( ) );
        }

        DMLogger.log.info( 0, false, "Opened database using file ${1}", db_file );
      }


      /**
       * @see DBLib.Connection.execute_query
       */
      public override void execute_query( string code ) throws DBLib.DBError.STATEMENT_ERROR
      {
        string errmsg;
        int ec = this.database.exec( code, null, out errmsg );
        if ( ec != Sqlite.OK )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database! %u: %s", code, ec, errmsg );
        }
      }

      /**
       * @see DBLib.Connection.get_result
       */
      public override DBLib.Result get_result( bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        return new DBLib.SQLite.Result( this, server_side_result );
      }

      /**
       * @see DBLib.Connection.get_insert_id
       */
      public override uint64 get_insert_id( )
      {
        return this.database.last_insert_rowid( );
      }

      public override string column_definition_to_sql( ColumnDefinition column )
      {
        return "";
      }

      /**
       * @see DBLib.Connection.quote
       */
      public override string quote( string val )
      {
        return "'".concat( val, "'" );
      }

      /**
       * This method will return the current SQLite error message.
       * @return The current SQLite error.
       */
      public string get_sqlite_error( )
      {
        if ( this.database == null )
        {
          return "unknown error";
        }
        else
        {
          return "[%04d] %s".printf( this.database.errcode( ), this.database.errmsg( ) );
        }
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

        string final_code = statment.to_sql( );
        if ( this.database == null )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Error while preparing statement %s! Database not open!", final_code );
        }

        int rc = this.database.prepare_v2( final_code, final_code.length, out stmt );
        if ( rc != Sqlite.OK )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Error while preparing statement %s! %s", final_code, this.get_sqlite_error( ) );
        }

        int next_bind_value = 0;
        void*[] binds = statment.get_binds( );
        Type[] types = statment.get_types( );
        for ( int i = 0; i < types.length; i ++ )
        {
          if ( types[i] == typeof( string ) )
          {
            stmt.bind_text( next_bind_value, (string)binds[ i ] );
          }
          else
          {
            throw new DBLib.DBError.STATEMENT_ERROR( "Unimplemente Type %s", types[ i ].name( ) );
          }

          next_bind_value ++;
        }

        int cols = stmt.column_count( );
        statment.result = this.get_result( false );
        if ( callback != null )
        {
          try
          {
            void*[] data = null;
            ulong[] array_lengths = null;
            while ( ( data = statment.result.fetchrow_binary( out array_lengths ) ) != null )
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
    }

    /**
     * This class is a implementation for the abstract class DBLib.Result
     */
    public class Result : DBLib.Result
    {
      /**
       * The MySQL connection which is used to fetch the result.
       */
      private DBLib.SQLite.Connection sqlite_conn;

      private int column_count;
      private unowned Sqlite.Statement stmt;

      /**
       * @see DBLib.Result
       * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the result from MySQL.
       */
      public Result( DBLib.SQLite.Connection conn, bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        base( conn, server_side_result );

        this.sqlite_conn = conn;
        this.stmt = conn.stmt;
        this.column_count = this.stmt.column_count( );
      }

      /*
       * @see DBLib.Result.fetchrow_hash
       */
      public override HashTable<string?,string?>? fetchrow_hash( )
      {
        HashTable<string?,string?> row = new HashTable<string?,string?>( str_hash, str_equal );
        if ( stmt.step( ) == Sqlite.ROW )
        {
          for ( int i = 0; i < this.column_count; i++ )
          {
            row.insert( this.stmt.column_name( i ), this.stmt.column_text( i ) );
          }
        }
        return row;

      }

      /**
       * @see DBLib.Result.fetchrow_array
       */
      public override string[]? fetchrow_array( )
      {
        string[] row = new string[ this.column_count ];
        if ( stmt.step( ) == Sqlite.ROW )
        {
          for ( int i = 0; i < this.column_count; i++ )
          {
            row[ i ] = this.stmt.column_text( i );
          }
          return row;
        }
        else
        {
          return null;
        }
      }


      /**
       * @see DBLib.Result.fetchrow_binary
       */
      public override void*[] fetchrow_binary( out ulong[] array_length )
      {
        array_length = new ulong[ this.column_count ];
        if ( stmt.step () == Sqlite.ROW )
        {
          void*[] data = new void*[ this.column_count ];
          for ( int i = 0; i < this.column_count; i++ )
          {
            array_length[ i ] = this.stmt.column_bytes( i );
            data[ i ] = this.stmt.column_blob( i );
          }
          return data;
        }
        else
        {
          return null;
        }
      }
    }
  }
}
