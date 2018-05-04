---
title: Connection Pool - ScalikeJDBC
---

## Connection Pool

<hr/>
### Configuration
<hr/>

See [/documentation/configuration](/documentation/configuration.html)


<hr/>
### Borrowing Connections
<hr/>

Simply just call `#borrow` method.

```scala
import scalikejdbc._
// default
val conn: java.sql.Connection = ConnectionPool.borrow()
// named
val conn: java.sql.Connection = ConnectionPool('named').borrow()
```

Be careful. The connection object should be released by yourself.

Basically using loan pattern is recommended to avoid human errors.

```scala
using(ConnectionPool.borrow()) { conn =>
  // do something
}
```

ScalikeJDBC wraps a `java.sql.Connection` object as a `scalikejdbc.DB` object.

```scala
using(DB(ConnectionPool.borrow())) { db =>
  // ...
}
```

`DB` object can provide `DBSession` for each operation.

```scala
using(DB(ConnectionPool.borrow())) { db =>
  db.readOnly { implicit session =>
    // ...
  }
}
```

Right, above code is too verbose! Using DB object make it much simpler.

You can simplify the same thins by using `DB` or `NamedDB` objects and it's the common usage of ScalikeJDBC.

```scala
// default
DB readOnly { implicit session =>
  // ...
}
// named
NamedDB('named) readOnly { implicit session =>
  // ...
}
```

<hr/>
### Reusing same DB instance several times
<hr/>

By default, `scalikejdbc.DB` or `scalikejdbc.NamedDB` instance always closes its connection (= releases and returns it to connection pools).

```scala
using(connectionPool.borrow()) { conn: java.sql.Connection => 
  val db: DB = DB(conn)

  db.localTx { implicit session =>
    sql"update something set name = ${name} where id = ${id}".update.apply()
  } // localTx or other APIs always close the connection to avoid connection leaks

  // the Connection already has been closed here!
  // java.sql.SQLException will be thrown!
  db.localTx { implicit session =>
    // ....
  }
}
```

When you prefer reusing the same Connection without releasing and returing to connection pools, use `DB#autoClose(Boolean)`.

```scala
using(connectionPool.borrow()) { conn: java.sql.Connection => 
  val db: DB = DB(conn)

  // set as auto-close disabled
  db.autoClose(false)

  db.localTx { implicit session =>
    sql"update something set name = ${name} where id = ${id}".update.apply()
  } // localTx won't close the current Connection

  // this block also works fine!
  db.localTx { implicit session =>
    // ....
  }
}
```

<hr/>
### Thread-local Connection Pattern
<hr/>

You can share DB connections as thread-local values. The connection should be released by yourself.

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

You can replace ConnectionPool settings safely on runtime. 

The old pool won't be abandoned until all the borrwoed connections are closed.

```scala
def doSomething = {
  ConnectionPool.singleton("jdbc:h2:mem:db1", "user", "pass")
  DB localTx { implicit s =>
    // long transaction...

    // overwrite singleton CP
    ConnectionPool.singleton("jdbc:h2:mem:db2", "user", "pass")

    // db1 connection pool is still available until this trancation is commited.
    // Newly borrowed connections will access db2.
  }
}
```

<hr/>
### Using Another ConnectionPool Implementation
<hr/>

If you want to use another one which is not Commons DBCP as the connection provider, You can also specify your own `ConnectionPoolFactory` as follows:

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
ConnectionPool.add('xxxx, url, user, password)
```

<hr/>
### Switching ConnectionPool Implementation by configuration
<hr/>

When `ConnectionPoolFactory` implementation already exists, it's possible to specify it by configuration. By default, commons-dbcp 1/2 and bonecp are already prepared. When you'd like to add another `ConnectionPoolFactory`, call repository's add method like this:

```scala
scalikejdbc.ConnectionPoolFactoryRepository.add("name", YourConnectionPoolFactory)
```

<hr/>
#### Default: commons-dbcp2

http://commons.apache.org/proper/commons-dbcp/

http://search.maven.org/#search%7Cgav%7C1%7Cg%3A%22org.apache.commons%22%20AND%20a%3A%22commons-dbcp2%22

```scala
ConnectionPool.singleton(url, user, password, 
  ConnectionPoolSettings(connectionPoolFactoryName = "commons-dbcp2"))
```

<hr/>
#### commons-dbcp 1.x

Previously, commons-dbcp 1.4 was the default connection pool for ScalikeJDBC. We don't recomment using the older one now, but if you need to choose 1.4 instead for some reason, specifying `commons-dbcp` works.

```scala
ConnectionPool.singleton(url, user, password, 
  ConnectionPoolSettings(connectionPoolFactoryName = "commons-dbcp"))
```

`commons-dbcp` dependency should be added by yourself.

```scala
libraryDependencies += "commons-dbcp" % "commons-dbcp" % "1.4"
```

<hr/>
#### BoneCP

http://jolbox.com/

```scala
ConnectionPool.singleton(url, user, password, 
  ConnectionPoolSettings(connectionPoolFactoryName = "bonecp"))
```

`bonecp` dependency should be added by yourself.

```scala
libraryDependencies += "com.jolbox" % "bonecp" % "0.8.0.RELEASE"
```

<hr/>
#### HikariCP

http://brettwooldridge.github.io/HikariCP/

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
libraryDependencies += "com.zaxxer" % "HikariCP" % "1.3.+"
```

