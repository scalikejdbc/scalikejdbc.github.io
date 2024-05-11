---
title: Connection Pool - ScalikeJDBC
---

## Connection Pool

<hr/>
### Configuration
<hr/>

For details on setting up your connection pool, please visit the [/documentation/configuration](/documentation/configuration.html) page.

<hr/>
### Borrowing Connections
<hr/>

To borrow a connection, simply use the `#borrow()` method:

```scala
import scalikejdbc._
// default connection
val conn: java.sql.Connection = ConnectionPool.borrow()
// named connection
val conn: java.sql.Connection = ConnectionPool("named").borrow()
```

It is important to manually release the connection. To prevent errors, employing the so-called loan pattern is recommended:

```scala
using(ConnectionPool.borrow()) { conn =>
  // do something
}
```

ScalikeJDBC encapsulates a `java.sql.Connection` in a `scalikejdbc.DB` object for safer, easier management:

```scala
using(DB(ConnectionPool.borrow())) { db =>
  // perform database operations
}
```

The `DB` object simplifies managing `DBSession` for different operations:

```scala
using(DB(ConnectionPool.borrow())) { db =>
  db.readOnly { implicit session =>
    // read-only operations
  }
}
```

However, this can be made simpler by directly using the `DB` or `NamedDB` objects, which is the most common way to use this library:

```scala
// default
DB readOnly { implicit session =>
  // ...
}
// named
NamedDB("named") readOnly { implicit session =>
  // ...
}
```

<hr/>
### Reusing same DB instance several times
<hr/>

By default, `scalikejdbc.DB` or `scalikejdbc.NamedDB` instance closes its connection automatically (= releases and returns it to connection pools).

```scala
using(connectionPool.borrow()) { (conn: java.sql.Connection) => 
  val db: DB = DB(conn)

  db.localTx { implicit session =>
    sql"update something set name = ${name} where id = ${id}".update.apply()
  } // localTx or other APIs always close the connection to avoid connection leaks

  // Connection is already closed here, using it again will throw an SQLException!
  db.localTx { implicit session =>
    // ....
  }
}
```

To reuse the same connection without returning it to the connection pool, disable auto-close through `DB#autoClose(Boolean)`:

```scala
using(connectionPool.borrow()) { (conn: java.sql.Connection) => 
  val db: DB = DB(conn)

  // set as auto-close disabled
  db.autoClose(false)

  db.localTx { implicit session =>
    sql"update something set name = ${name} where id = ${id}".update.apply()
  } // localTx won't close the current Connection

  // Reuse the connection for another transaction
  db.localTx { implicit session =>
    // ....
  }
}
```

<hr/>
### Thread-local Connection Pattern
<hr/>

Connections can be managed as thread-local variables, needing explicit closure (meaning you're responsible to manually close the session):

```scala
def init() = {
  val newDB = ThreadLocalDB.create(conn)
  newDB.begin()
}
// after that..
def action() = {
  val db = ThreadLocalDB.load()
}
def finalize() = {
  try { ThreadLocalDB.load().close() } catch { case e => }
}
```

<hr/>
### Replacing ConnectionPool on Runtime
<hr/>

ConnectionPool settings can be safely changed at runtime without disrupting existing connections:

```scala
def doSomething = {
  ConnectionPool.singleton("jdbc:h2:mem:db1", "user", "pass")
  DB localTx { implicit s =>
    // long transaction...

    // overwrite singleton CP
    ConnectionPool.singleton("jdbc:h2:mem:db2", "user", "pass")

    // db1 connection pool is still available until this trancation is committed.
    // Newly borrowed connections will access db2.
  }
}
```

<hr/>
### Using Another ConnectionPool Implementation
<hr/>

To utilize a different connection pool provider, such as c3p0, define your own `ConnectionPoolFactory`:

```scala
/**
 * c3p0 Connection Pool Factory
 */
object C3P0ConnectionPoolFactory extends ConnectionPoolFactory {
  override def apply(url: String, user: String, password: String,
    settings: ConnectionPoolSettings = ConnectionPoolSettings()) = {
    new C3P0ConnectionPool(url, user, password, settings)
  }
}

/**
 * c3p0 Connection Pool
 */
class C3P0ConnectionPool(
  override val url: String,
  override val user: String,
  password: String,
  override val settings: ConnectionPoolSettings = ConnectionPoolSettings())
  extends ConnectionPool(url, user, password, settings) {

  import com.mchange.v2.c3p0._
  private[this] val _dataSource = new ComboPooledDataSource
  _dataSource.setJdbcUrl(url)
  _dataSource.setUser(user)
  _dataSource.setPassword(password)
  _dataSource.setInitialPoolSize(settings.initialSize)
  _dataSource.setMaxPoolSize(settings.maxSize);
  _dataSource.setCheckoutTimeout(settings.connectionTimeoutMillis.toInt);

  override def dataSource: DataSource = _dataSource
  override def borrow(): Connection = dataSource.getConnection()
  override def numActive: Int = _dataSource.getNumBusyConnections(user, password)
  override def numIdle: Int = _dataSource.getNumIdleConnections(user, password)
  override def maxActive: Int = _dataSource.getMaxPoolSize
  override def maxIdle: Int = _dataSource.getMaxPoolSize
  override def close(): Unit = _dataSource.close()
}

implicit val factory = C3P0ConnectionPoolFactory
ConnectionPool.add("xxxx", url, user, password)
```

<hr/>
### Switching ConnectionPool Implementation by configuration
<hr/>

When a `ConnectionPoolFactory` implementation is already in place, it can be configured for use. By default, ScalikeJDBC comes pre-configured with commons-dbcp 1/2 and bonecp. If you need to integrate a different `ConnectionPoolFactory`, you can add it to the repository as follows:

```scala
scalikejdbc.ConnectionPoolFactoryRepository.add("name", YourConnectionPoolFactory)
```

<hr/>
#### Default: commons-dbcp2

https://commons.apache.org/proper/commons-dbcp/

https://search.maven.org/search?q=g:org.apache.commons%20AND%20a:commons-dbcp2

```scala
ConnectionPool.singleton(url, user, password, 
  ConnectionPoolSettings(connectionPoolFactoryName = "commons-dbcp2"))
```

<hr/>
#### commons-dbcp 1.x

Previously, commons-dbcp 1.4 served as the default connection pool for ScalikeJDBC. While it is no longer recommended, if there is a specific reason to use version 1.4, it can still be specified as `commons-dbcp` in the configuration.

```scala
ConnectionPool.singleton(url, user, password, 
  ConnectionPoolSettings(connectionPoolFactoryName = "commons-dbcp"))
```

`commons-dbcp` dependency should be added by yourself.

```scala
libraryDependencies += "commons-dbcp" % "commons-dbcp" % "1.4"
```

<hr/>
#### HikariCP

https://github.com/brettwooldridge/HikariCP

HikariCP expects dataSourceClassName. So we recommend using DataSourceConnectionPool.

```scala
val dataSource: DataSource = {
  val ds = new HikariDataSource()
  ds.setDataSourceClassName(dataSourceClassName)
  ds.addDataSourceProperty("url", url)
  ds.addDataSourceProperty("user", user)
  ds.addDataSourceProperty("password", password)
  ds
}
ConnectionPool.singleton(new DataSourceConnectionPool(dataSource))
```

`HikariCP` dependency should be added by yourself.

```scala
libraryDependencies += "com.zaxxer" % "HikariCP" % "3.+"
```

