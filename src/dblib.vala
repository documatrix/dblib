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
    MYSQL,
    SQLITE;
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
    public static Connection connect( DBType db_type, string connection_string, string? user = null, string? password = null ) throws DBError.CONNECTION_ERROR
    {
      DMLogger.log.debug( 0, false, "Connecting to database." );

      DataSourceName dsn = new DataSourceName( connection_string );

      switch ( db_type )
      {
        case DBType.MYSQL:
          DMLogger.log.debug( 0, false, "Connecting to a MySQL database using connection string ${1}, user ${2} and password ${3}", connection_string, user ?? "(null)", "******" );
          return new DBLib.MySQL.Connection( dsn, user, password );
        case DBType.SQLITE:
          DMLogger.log.debug( 0, false, "Connecting to a SQLite database using connection string ${1}", connection_string );
          return new DBLib.SQLite.Connection( dsn );

        default:
          throw new DBError.CONNECTION_ERROR( "Undefined database type passed!" );
      }
    }

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

    public abstract string column_definition_to_sql( ColumnDefinition column );

    public abstract string quote( string val );

    public SelectStatement select( ... )
    {
      va_list args = va_list( );

      string[] columns = {};
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        columns += (!)str;
      }

      return new SelectStatement( this, columns );
    }

    public InsertStatement insert( )
    {
      return new InsertStatement( this );
    }

    public UpdateStatement update( string table_name )
    {
      return new UpdateStatement( this, table_name );
    }

    public DeleteStatement @delete( )
    {
      return new DeleteStatement( this );
    }

    public CreateTableStatement create_table( string table_name )
    {
      return new CreateTableStatement( this, table_name );
    }

    public Statement prepare( string stmt )
    {
      return new Statement( this, stmt );
    }

    /**
     * This method will replace the question marks in the statement code by the given parameters and will execute
     * the statement.
     * @param server_side_result This parameter indicates if the result of the statement should be stored on the server (true) or loaded to the client (false).
     * @return The executed statement.
     * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters or while executing the statement.
     * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the resultset.
     */
    public abstract DBLib.Statement execute_binary( DBLib.Statement statment, SelectStatementBinaryCallback? callback = null ) throws DBLib.DBError.STATEMENT_ERROR, DBLib.DBError.RESULT_ERROR;


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
     * This method will replace the question marks in the statement code by the given parameters and will execute
     * the statement.
     * @return The executed statement.
     * @throws DBLib.DBError.STATEMENT_ERROR if an error occurs while replacing the parameters or while executing the statement.
     * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the resultset.
     */
    public DBLib.Statement execute_statment( DBLib.Statement statment, SelectStatementCallback? callback = null ) throws DBLib.DBError.STATEMENT_ERROR, DBLib.DBError.RESULT_ERROR
    {
      if ( callback == null )
      {
        this.execute_binary( statment, null );
      }
      else
      {
        this.execute_binary( statment, ( data, array_lengths ) =>
        {
          string[] values = new string[ array_lengths.length ];
          values.length = array_lengths.length;
          for ( int i = 0; i < array_lengths.length; i ++ )
          {
            char* string_data = data[ i ];
            values[ i ] = (string)string_data;
          }

          callback( values );
          return 0;
        } );
      }

      return statment;
    }
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
    public Result( DBLib.Connection conn, bool server_side_result )
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

  public delegate int SelectStatementCallback( string[] values );

  public delegate int SelectStatementBinaryCallback( char** data, ulong[] array_length );

  public class Statement : GLib.Object
  {
    public Connection conn;

    public Result result;

    public string code;

    private string[] binds = {};

    protected uint16 next_bind_value = 1;

    /**
     * This constructor creates a new Statement object which will be executed on the given connection.
     * It will also replace the given parameters from a va_list with the quotation marks in the statement code.
     * @param conn A connection object which will be used to execute the statement.
     * @param code The statement code.
     * @param params A va_list object which may contain strings.
     */
    public Statement( Connection conn, string code)
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
      this.conn = conn;
      this.code = code;

      unowned string? param;
      while ( ( param = params.arg( ) ) != null )
      {
        this.binds += param;
      }
    }

    public Statement execute( ) throws DBLib.DBError
    {
      this.conn.execute_statment( this );
      this.result = this.conn.get_result( false );
      return this;
    }

    public virtual string to_sql( )
    {
      return this.code;
    }

    public void set_params( string[] binds )
    {
      this.binds = binds;
    }

    protected void add_bind( string bind )
    {
      this.binds += bind;
    }

    public string[] get_binds( )
    {
      return this.binds;
    }
  }

  public class InsertStatement : Statement
  {
    public string table;

    private string[] _columns = {};

    public InsertStatement( Connection connection )
    {
      base( connection, "" );
    }

    public InsertStatement into( string table )
    {
      this.table = table;

      return this;
    }

    public InsertStatement columns( ... )
    {
      va_list args = va_list( );
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        this._columns += str;
      }

      return this;
    }

    public InsertStatement values( ... )
    {
      va_list args = va_list( );
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        this.add_bind( str );
      }

      return this;
    }

    public override string to_sql( )
    {
      string[] qm = {};

      int bind_vars = this.get_binds( ).length;
      for ( int i = 0; i < bind_vars; i ++ )
      {
        qm += "?";
      }

      return "INSERT INTO %s (%s) values (%s)".printf(
                     this.table,
                     string.joinv( ",", this._columns ),
                     string.joinv( ",", qm )
                   );
    }
  }

  public class UpdateStatement : Statement
  {
    public string table;

    public string where_clause = "";

    private string[] columns = {};

    public UpdateStatement( Connection connection, string table )
    {
      base( connection, "" );
      this.table = table;
    }

    public UpdateStatement @set( string column, string val )
    {
      this.columns += column + " = ?";
      this.add_bind( val );

      return this;
    }

    public UpdateStatement where( string clause, ... )
    {
      this.where_clause = "WHERE " + clause;

      va_list args = va_list( );
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        this.add_bind( str );
      }

      return this;
    }

    public override string to_sql( )
    {
      return "UPDATE %s SET %s %s".printf(
                     this.table,
                     string.joinv( ",", this.columns ),
                     this.where_clause
                   );
    }
  }

  public enum DataType
  {
    TINYINT,
    SMALLINT,
    MEDIUMINT,
    INT,
    BIGINT,
    BIT,
    FLOAT,
    DOUBLE,
    DECIMAL,
    CHAR,
    VARCHAR,
    TINYTEXT,
    TEXT,
    MEDIUMTEXT,
    LONGTEXT,
    BINARY,
    VARBINARY,
    TINYBLOB,
    BLOB,
    MEDIUMBLOB,
    LONGBLOB,
    DATE,
    TIME,
    YEAR,
    DATETIME,
    TIMESTAMP;

    public string to_string( )
    {
      switch ( this )
      {
        case TINYINT:
          return "TINYINT";
        case SMALLINT:
          return "SMALLINT";
        case MEDIUMINT:
          return "MEDIUMINT";
        case INT:
          return "INT";
        case BIGINT:
          return "BIGINT";
        case BIT:
          return "BIT";
        case FLOAT:
          return "FLOAT";
        case DOUBLE:
          return "DOUBLE";
        case DECIMAL:
          return "DECIMAL";
        case CHAR:
          return "CHAR";
        case VARCHAR:
          return "VARCHAR";
        case TINYTEXT:
          return "TINYTEXT";
        case TEXT:
          return "TEXT";
        case MEDIUMTEXT:
          return "MEDIUMTEXT";
        case LONGTEXT:
          return "LONGTEXT";
        case BINARY:
          return "BINARY";
        case VARBINARY:
          return "VARBINARY";
        case TINYBLOB:
          return "TINYBLOB";
        case BLOB:
          return "BLOB";
        case MEDIUMBLOB:
          return "MEDIUMBLOB";
        case LONGBLOB:
          return "LONGBLOB";
        case DATE:
          return "DATE";
        case TIME:
          return "TIME";
        case YEAR:
          return "YEAR";
        case DATETIME:
          return "DATETIME";
        case TIMESTAMP:
          return "TIMESTAMP";
      }
      return "";
    }
  }

  public enum DefaultValueType
  {
    NO_DEFAULT,
    NULL,
    CURRENT_TIMESTAMP,
    AUTO_INCREMENT,
    CUSTOM;
  }

  public class ColumnDefinition : GLib.Object
  {
    public string name;
    public DataType data_type;
    public uint32 size;
    public bool is_unsigned;
    public bool is_nullable;
    public DefaultValueType default_value_type;
    public string default_value;
    public bool is_primary_key;

    public ColumnDefinition( string name, DataType data_type, uint32 size, bool is_unsigned, bool is_nullable, DefaultValueType default_value_type, string default_value = "", bool is_primary_key = false )
    {
      this.name = name;
      this.data_type = data_type;
      this.size = size;
      this.is_unsigned = is_unsigned;
      this.is_nullable = is_nullable;
      this.default_value_type = default_value_type;
      this.default_value = default_value;
      this.is_primary_key = is_primary_key;
    }
  }

  public class CreateTableStatement : Statement
  {
    public string table;

    private ColumnDefinition[] column_definitions = {};

    public CreateTableStatement( Connection connection, string table )
    {
      base( connection, "" );
      this.table = table;
    }

    public CreateTableStatement columns( ColumnDefinition[] column_definitions )
    {
      this.column_definitions = column_definitions;
      return this;
    }

    public override string to_sql( )
    {
      string[] columns = {};
      string primary_key = "";
      foreach ( unowned ColumnDefinition c in this.column_definitions )
      {
        columns += this.conn.column_definition_to_sql( c );
        if ( c.is_primary_key )
        {
          primary_key = "PRIMARY KEY (%s)".printf( this.conn.quote( c.name ) );
        }
      }
      // TODO handle constraints correctly
      columns += primary_key;

      return "CREATE TABLE IF NOT EXISTS %s ( %s )".printf(
        this.conn.quote( this.table ),
        string.joinv( ",", columns )
      );
    }
  }

  public class DeleteStatement : Statement
  {
    public string table;

    public string where_clause = "";

    public DeleteStatement( Connection connection )
    {
      base( connection, "" );
    }

    public DeleteStatement from( string table )
    {
      this.table = table;

      return this;
    }

    public DeleteStatement where( string clause, ... )
    {
      this.where_clause = "WHERE " + clause;

      va_list args = va_list( );
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        this.add_bind( str );
      }

      return this;
    }

    public override string to_sql( )
    {
      return "DELETE FROM %s %s".printf(
                     this.table,
                     this.where_clause
                   );
    }
  }

  public class SelectStatement : Statement
  {
    public string[] columns;

    public string table_name;

    private string? where_clause = null;

    private string? _limit = null;

    private string[] _order_by = {};

    private string[] _group_by = {};

    public SelectStatement( Connection connection, string[] columns )
    {
      base( connection, "" );
      this.columns = columns;
    }

    public SelectStatement.with_sql( Connection connection, string sqlcode )
    {
      base( connection, code );
    }

    public SelectStatement from( string table_name )
    {
      this.table_name = table_name;

      return this;
    }

    private void add_to_where_clause( string clause )
    {
      if ( this.where_clause == null )
      {
        this.where_clause = "where ";
      }
      else
      {
        this.where_clause += " and ";
      }

      this.where_clause += "(%s)".printf( clause );
    }

    public SelectStatement where( string clause, ... )
    {
      this.add_to_where_clause( clause );

      va_list args = va_list( );
      for ( string? str = args.arg<string?>( ); str != null; str = args.arg<string?>( ) )
      {
        this.add_bind( str );
      }

      return this;
    }

    public SelectStatement wherev( string clause, string[] args )
    {
      this.add_to_where_clause( clause );

      foreach ( string str in args )
      {
        this.add_bind( str );
      }

      return this;
    }

    public SelectStatement limit( string limit )
    {
      this._limit = limit;
      return this;
    }

    public SelectStatement order_by( string order_by )
    {
      this._order_by += order_by;
      return this;
    }

    public SelectStatement group_by( string group_by )
    {
      this._group_by += group_by;
      return this;
    }

    public void exec( SelectStatementCallback callback ) throws DBError
    {
      this.conn.execute_statment( this, callback );
    }

    public void execute_binary( SelectStatementBinaryCallback callback ) throws DBError
    {
      this.conn.execute_binary( this, callback );
    }

    public string get_suffix( )
    {
      string suffix = "";
      if ( this._group_by.length > 0 )
      {
        suffix = suffix.concat( " GROUP BY ", string.joinv( ", ", this._group_by ) );
      }
      if ( this._order_by.length > 0 )
      {
        suffix = suffix.concat( " ORDER BY ", string.joinv( ", ", this._order_by ) );
      }
      if ( this._limit != null )
      {
        suffix = suffix.concat( " LIMIT ", this._limit );
      }
      return suffix;
    }

    public override string to_sql( )
    {
      if ( this.code != "" )
      {
        return base.to_sql( );
      }

      return "select %s from %s %s".printf( string.joinv( ", ", this.columns ), this.table_name, this.where_clause ?? "" ) + this.get_suffix( );
    }
  }
}
