/*
 * DBLib
 * (c) by DocuMatrix GmbH
 */

namespace DBLib
{
  /**
   * This errordomain contains different errors which may occur using
   * the DBLib.
   */
  public errordomain DBError
  {
    CONNECTION_ERROR,
    STATEMENT_ERROR,
    RESULT_ERROR;
  }

  /**
   * This enum contains the possible database connection types.
   */
  public enum DBType
  {
    MYSQL;
  }

  /**
   * This class represents a database connection and provides methods
   * which have to be implemented by the database specific classes.
   */
  public abstract class Connection
  {
    /**
     * The DataSourceName object which was used to connect to the MySQL database.
     */
    public DataSourceName dsn;

    /**
     * Use this method to connect to a specific database using given connection
     * parameters.
     * @param db_type The type of the database connection. Depending on that value
     *                the specific class will be selected.
     * @param connection_string The connection string which should be passed to the driver.
     * @param user The username which should be used to connect to the database.
     * @param password The password which should be used to connect to the database.
     * @return A connection object which represents the database connection.
     * @throws DBError This error will be thrown if an error occurs while connecting to the database.
     */
    public static Connection connect( DBType db_type, string connection_string, string? user, string? password ) throws DBError.CONNECTION_ERROR
    {
      DMLogger.log.debug( 0, false, "Connecting to database." );

      DataSourceName dsn = new DataSourceName( connection_string );

      switch ( db_type )
      {
        case DBType.MYSQL:
          DMLogger.log.debug( 0, false, "Connecting to a MySQL database using connection string ${1}, user ${2} and password ${3}", connection_string, user ?? "(null)", password ?? "(null)" );
          return new DBLib.MySQL.Connection( dsn, user, password );

        default:
          throw new DBError.CONNECTION_ERROR( "Undefined database type passed!" );
      }
    }

    /**
     * This method can be used to create (prepare) a statement using this connection.
     * @param stmt A string which will be used as statement code.
     * @return A new created statement object.
     */
    public Statement prepare( string stmt )
    {
      return new Statement( this, stmt );
    }

    /**
     * This method will execute a given statement.
     * The statement will be prepared first. Then the given parameters will be substituted.
     * Then the statement is executed.
     * @param stmt A string which will be used as statement code.
     * @param ... Values which will be used to replace given question marks with the escaped values.
     * @return The prepared and executed statement.
     * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while executing the statement.
     * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the resultset.
     */
    public DBLib.Statement execute( string stmt, ... ) throws DBLib.DBError.STATEMENT_ERROR, DBLib.DBError.RESULT_ERROR
    {
      va_list params = va_list( );
      return new Statement.with_params( this, stmt, params ).execute( );
    }

    /**
     * This method will escape the given string using the database specific escape method.
     * @param val The value which should be escaped so it can be used in a statement as string value.
     * @return The given value which was escaped using the database specific escape method.
     */
    public abstract string escape( string? val );

    /**
     * This method will execute the given query using the database specific execute_query method.
     * @param code The query code which should be executed.
     * @throws DBLib.DBError.STATEMENT_ERROR when an error occurs while executing the given query.
     */
    public abstract void execute_query( string code ) throws DBLib.DBError.STATEMENT_ERROR;

    /**
     * This method will fetch the current result using the database specific connector.
     * @param server_side_result @see DBLib.Result.server_side_result
     * @throws DBLib.DBError.RESULT_ERROR if an error occured while fetching the result.
     */
    public abstract DBLib.Result get_result( bool server_side_result ) throws DBLib.DBError.RESULT_ERROR;

    /**
     * This method will return the last auto_incremented value.
     * It will try to get this value using a method on the database specific connector.
     */
    public abstract uint64 get_insert_id( );
  }

  /**
   * This class can be used to parse and use data source names.
   */
  public class DataSourceName : GLib.Object
  {
    /**
     * Every value in the given dsn-string will be inserted into this hash.
     */
    public HashTable<string?,string?> values;

    /**
     * Create a new DataSourceName object using a given dsn string.
     * @param dsn A data source name string which will be parsed.
     */
    public DataSourceName( string dsn )
    {
      this.values = new HashTable<string?,string?>( str_hash, str_equal );

      string[] parts = dsn.split( ";" );
      for ( int i = 0; i < parts.length; i ++ )
      {
        string[] kv = parts[ i ].split( "=" );

        if ( kv.length == 2 )
        {
          this.values[ kv[ 0 ] ] = kv[ 1 ];
        }
        else
        {
          DMLogger.log.warning( 0, false, "Invalid token '${1}' in data source name '${2}'!", parts[ i ], dsn );
        }
      }
    }

    /**
     * This method will return the value for the given key.
     * @param key A key whichs value should be returned.
     * @return The value for the given key.
     */
    public new string get( string key )
    {
      return this.values[ key ];
    }
  }

  /**
   * Objects of this class represent a resultset which was fetched from the database server.
   */
  public abstract class Result : GLib.Object
  {
    /**
     * This variable indicates if the resultset should be stored on the server or stored on the client.
     */
    public bool server_side_result;

    /**
     * The connection which should be used to fetch the resultset.
     */
    public DBLib.Connection conn;

    /**
     * This constructor creates a new result object using a given connection and server_side_result setting.
     * @param conn The connection to use to fetch the resultset.
     * @param server_side_result @see DBLib.Result.server_side_result.
     */
    public Result( DBLib.MySQL.Connection conn, bool server_side_result )
    {
      this.conn = conn;
      this.server_side_result = server_side_result;
    }

    /**
     * This method will fetch the next row from the current resultset and will return the values as hash.
     * The hash keys are the column names returned from the database.
     * @return The next row in the resultset or null if no more rows exist.
     */
    public abstract HashTable<string?,string?>? fetchrow_hash( );

    /**
     * This method will fetch the next row from the current resultset and will return the values as array.
     * @return The next row in the resultset or null if no more rows exist.
     */
    public abstract string[]? fetchrow_array( );

    /**
     * This method will fetch the next row from the current resultset and will return the values as array.
     * @return The next row in the resultset or null if no more rows exist.
     */
    public abstract char** fetchrow_binary( out ulong[] array_length );
  }

  /**
   * Objects of this class represent a statement which can be executed using a DBLib.Connection.
   */
  public class Statement : GLib.Object
  {
    /**
     * This connection will be used to execute the statement.
     */
    public Connection conn;

    /**
     * This is the code of the statement.
     */
    public string code;

    /**
     * This array may contain parameters which will used to generate the final code.
     */
    private string?[] params = { };

    /**
     * This variable contains the result of the query (even if the statement was no select statement).
     */
    public DBLib.Result result;

    /**
     * This constructor creates a new Statement object which will be executed on the given connection.
     * @param conn A connection object which will be used to execute the statement.
     * @param code The statement code.
     */
    public Statement( Connection conn, string code )
    {
      this.conn = conn;
      this.code = code;
    }

    /**
     * This constructor creates a new Statement object which will be executed on the given connection.
     * It will also replace the given parameters from a va_list with the quotation marks in the statement code.
     * @param conn A connection object which will be used to execute the statement.
     * @param code The statement code.
     * @param params A va_list object which may contain strings.
     */
    public Statement.with_params( Connection conn, string code, va_list params )
    {
      this( conn, code );

      unowned string? param;
      while ( ( param = params.arg( ) ) != null )
      {
        this.params += param;
      }
    }

    /**
     * This method can be used to set the statement parameters.
     * It will overwrite any previously set parameters.
     */
    public void set_params( string?[] params )
    {
      this.params = params;
    }


    /**
     * This method will generate the final statement code using the given code and specified parameters.
     * It will replace question marks in the statement code and replace them with the escaped params.
     * @return The final statement code.
     * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters.
     */
    public string get_final_code( ) throws DBLib.DBError.STATEMENT_ERROR
    {
      char c;
      int code_length = this.code.length;
      int next_parameter = 0;
      StringBuilder final_code = new StringBuilder.sized( code_length );

      for ( int i = 0; i < code_length; i ++ )
      {
        c = this.code[ i ];

        if ( c == '?' )
        {
          /* Get the next parameter and escape it. */
          if ( next_parameter >= this.params.length )
          {
            /* There is no more parameter! */
            DMLogger.log.error( 0, false, "Error while generating final statement code for statement ${1}! Expected ${1} parameters but only ${3} were sepcified! ${4}", this.code, ( next_parameter + 1 ).to_string( ), this.params.length.to_string( ), this.get_params_string( )
            );
            for ( int j = 0; j < this.params.length; j ++ )
            {
              DMLogger.log.error( 0, false, "Parameter ${1}: ${2}", ( j + 1 ).to_string( ), this.params[ j ] ?? "NULL" );
            }
            throw new DBLib.DBError.STATEMENT_ERROR( "Error while generating final statement code for statement %s! Expected %d parameters but only %d were sepcified! %s", this.code, next_parameter + 1, this.params.length, this.get_params_string( ) );
          }

          final_code.append( this.conn.escape( this.params[ next_parameter ] ) );
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
    public string get_params_string( )
    {
      string param_string = "";
      for( int i = 0; i < this.params.length; i ++ )
      {
        param_string += "\nParams %d: %s".printf( i, this.params[ i ] );
      }
      return param_string;
    }

    /**
     * This method will replace the question marks in the statement code by the given parameters and will execute
     * the statement.
     * @param server_side_result This parameter indicates if the result of the statement should be stored on the server (true) or loaded to the client (false).
     * @return The executed statement.
     * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters or while executing the statement.
     * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the resultset.
     */
    public DBLib.Statement execute( bool server_side_result = false ) throws DBLib.DBError.STATEMENT_ERROR, DBLib.DBError.RESULT_ERROR
    {
      string final_code;
      if ( this.params.length > 0 )
      {
        final_code = this.get_final_code( );
      }
      else
      {
        final_code = this.code;
      }

      this.conn.execute_query( final_code );
      this.result = this.conn.get_result( server_side_result );

      return this;
    }
  }
}
