using Testlib;
using DBLib;

public class TestDBLib
{
  public static int main( string[] args )
  {
    GLib.Test.init( ref args );

    GLib.TestSuite ts_dblib = new GLib.TestSuite( "DBLib" );
    GLib.TestSuite.get_root( ).add_suite( ts_dblib );

    GLib.TestSuite ts_data_source_name = new GLib.TestSuite( "DataSourceName" );
    ts_data_source_name.add(
      new GLib.TestCase(
        "test_n",
        TestDBLib.default_setup,
        TestDBLib.test_data_source_name_n,
        TestDBLib.default_teardown
      )
    );
    ts_dblib.add_suite( ts_data_source_name );
    
    GLib.TestSuite ts_connection = new GLib.TestSuite( "Connection" );
    
    ts_connection.add(
      new GLib.TestCase(
        "test_f_connect",
        TestDBLib.default_setup,
        TestDBLib.test_connection_f_connect,
        TestDBLib.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
        "test_f_execute",
        TestDBLib.default_setup,
        TestDBLib.test_connection_f_execute,
        TestDBLib.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
        "test_f_escape",
        TestDBLib.default_setup,
        TestDBLib.test_connection_f_escape,
        TestDBLib.default_teardown
      )
    );
    
    ts_dblib.add_suite( ts_connection );

    GLib.TestSuite ts_mysql = new GLib.TestSuite( "MySQL" );

    GLib.TestSuite ts_mysql_connection = new GLib.TestSuite( "Connection" );
    ts_mysql_connection.add(
      new GLib.TestCase(
        "test_f_connect",
        TestDBLib.default_setup,
        TestDBLib.test_mysql_connection_f_connect,
        TestDBLib.default_teardown
      )
    );
    ts_mysql.add_suite( ts_mysql_connection );

    ts_dblib.add_suite( ts_mysql );

    GLib.TestSuite ts_statement = new GLib.TestSuite( "Statement" );
    
    ts_statement.add(
      new GLib.TestCase(
        "test_n",
        TestDBLib.default_setup,
        TestDBLib.test_statement_n,
        TestDBLib.default_teardown
      )
    );
    
    ts_dblib.add_suite( ts_statement );

    GLib.TestSuite ts_result = new GLib.TestSuite( "Result" );
    
    ts_result.add(
      new GLib.TestCase(
        "test_f_fetchrow_array",
        TestDBLib.default_setup,
        TestDBLib.test_result_f_fetchrow_array,
        TestDBLib.default_teardown
      )
    );
    ts_result.add(
      new GLib.TestCase(
        "test_f_fetchrow_hash",
        TestDBLib.default_setup,
        TestDBLib.test_result_f_fetchrow_hash,
        TestDBLib.default_teardown
      )
    );
    
    ts_dblib.add_suite( ts_result );
    
    GLib.Test.run( );
    return 0;
  }

  /**
   * This testcase tests the constructor of the DataSourceName class.
   */
  public static void test_data_source_name_n( )
  {
    DBLib.DataSourceName dsn = new DBLib.DataSourceName( "var1=val1;var2=val2;var3;var2=val2.1" );
    assert( dsn != null );
    assert( dsn[ "var1" ] == "val1" );
    assert( dsn[ "var2" ] == "val2.1" );
    assert( dsn[ "var3" ] == null );
  }
  
  /**
   * This testcase tests the connection to a database.
   */
  public static void test_connection_f_connect( )
  {
    try
    {
      DBLib.Connection c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=not_existing;database=none", null, null );
      assert_not_reached( );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert( true );
    }
  }

  /**
   * This testcase tests the connection to a MySQL database.
   */
  public static void test_mysql_connection_f_connect( )
  {
    try
    {
      DBLib.Connection c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }
  }

  /**
   * This testscase tests the constructor of the Statement class.
   */
  public static void test_statement_n( )
  {
    DBLib.Connection? c = null;

    try
    {
      c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost;database=mysql", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }

    string code = "select * from user";
    Statement s = new Statement( c, code );
    assert( s != null );
    assert( s.code == code );
    assert( s.conn == c );
  }

  /**
   * This testscase tests the execute of the Connection class specifing parameters.
   */
  public static void test_connection_f_execute( )
  {
    DBLib.Connection? c = null;

    try
    {
      c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost;database=mysql", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }

    try
    {
      string code = "select * from user where User = ?";
      Statement s = c.execute( code, "root" );
      assert( s != null );
      assert( s.code == code );
      assert( s.conn == c );
      assert( s.result != null );
    }
    catch ( Error e )
    {
      assert_not_reached( );
    }
  }

  /**
   * This testscase tests the escape method of the Connection class.
   */
  public static void test_connection_f_escape( )
  {
    DBLib.Connection? c = null;

    try
    {
      c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost;database=mysql", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }
  }
  
  /**
   * This is the default setup method for the DBLib tests.
   * It will setup a DMLogger.Logger object and then invoke the default_setup method from Testlib.
   */
  public static void default_setup( )
  {
    DMLogger.log = new DMLogger.Logger( null );
    DMLogger.log.set_config( true, "../log/messages.mdb", false );
    DMLogger.log.start_threaded( );
    Testlib.default_setup( );
  }

  /**
   * This is the default teardown method for the DBLib tests.
   * It will stop the DMLogger.Logger and then invoke the default_teardown method from Testlib.
   */
  public static void default_teardown( )
  {
    if ( DMLogger.log != null )
    {
      DMLogger.log.stop( );
    }
    Testlib.default_teardown( );
  }

  /**
   * This testscase tests the fetchrow_array method of the DBLib.Result object.
   */
  public static void test_result_f_fetchrow_array( )
  {
    DBLib.Connection? c = null;

    try
    {
      c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost;database=mysql", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }

    try
    {
      string code = "select User from user where User = ? limit 1";
      Statement s = c.execute( code, "root" );
      assert( s != null );
      assert( s.result != null );

      string[]? row = s.result.fetchrow_array( );
      assert( row != null );
      assert( row.length == 1 );
      assert( row[ 0 ] == "root" );

      row = s.result.fetchrow_array( );
      assert( row == null );
    }
    catch ( Error e )
    {
      assert_not_reached( );
    }
  }

  /**
   * This testscase tests the fetchrow_hash method of the DBLib.Result object.
   */
  public static void test_result_f_fetchrow_hash( )
  {
    DBLib.Connection? c = null;

    try
    {
      c = DBLib.Connection.connect( DBLib.DBType.MYSQL, "hostname=localhost;database=mysql", "root", null );
      assert( c != null );
      assert( c.dsn != null );
    }
    catch ( DBLib.DBError.CONNECTION_ERROR e )
    {
      assert_not_reached( );
    }

    try
    {
      string code = "select User from user where User = ? limit 1";
      Statement s = c.execute( code, "root" );
      assert( s != null );
      assert( s.result != null );

      HashTable<string?,string?>? row = s.result.fetchrow_hash( );
      assert( row != null );
      assert( row[ "User" ] == "root" );

      row = s.result.fetchrow_hash( );
      assert( row == null );
    }
    catch ( Error e )
    {
      assert_not_reached( );
    }
  }
}
