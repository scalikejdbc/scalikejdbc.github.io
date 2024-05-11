---
title: Configuration - ScalikeJDBC
---

## Configuration

<hr/>
To use ScalikeJDBC, the following three factors need to be proplery configured.

<hr/>
### Loading JDBC Drivers
<hr/>

Before using JDBC drivers, they must be explicitly loaded using either:

```
Class.forName(String)
```

or

```
java.sql.DriverManager.registerDriver(java.sql.Driver)
```

Many modern JDBC drivers, however, automatically load themselves when included in the classpath. Nonetheless, when you're using `scalikejdbc-config` or `scalikejdbc-play-plugin`, these handle the above loading process for safety.

<hr/>
### Connection Pool Settings
<hr/>

It's required to initialize a ConnectionPool at the start of your applications:

```scala
import scalikejdbc._

// after loading JDBC drivers
ConnectionPool.singleton(url, user, password)
ConnectionPool.add("foo", url, user, password)

val settings = ConnectionPoolSettings(
  initialSize = 5,
  maxSize = 20,
  connectionTimeoutMillis = 3000L,
  validationQuery = "select 1 from dual")

// all the connections are released, old connection pool will be abandoned
ConnectionPool.add("foo", url, user, password, settings)
```

For using an external DataSource, such as an application server's connection pool, connect via JNDI:

```scala
import javax.naming._
import javax.sql._
val ds = (new InitialContext)
  .lookup("java:/comp/env").asInstanceOf[Context]
  .lookup(name).asInstanceOf[DataSource]

import scalikejdbc._
ConnectionPool.singleton(new DataSourceConnectionPool(ds))
ConnectionPool.add("foo", new DataSourceConnectionPool(ds))
```

Here's how `ConnectionPool` and `ConnectionPoolSettings` parameters look:

```scala
abstract class ConnectionPool(
  val url: String,
  val user: String,
  password: String,
  val settings: ConnectionPoolSettings)
```

```scala
case class ConnectionPoolSettings(
  initialSize: Int,
  maxSize: Int,
  connectionTimeoutMillis: Long,
  validationQuery: String)
```

Further details in the [source code](https://github.com/scalikejdbc/scalikejdbc/blob/master/scalikejdbc-core/src/main/scala/scalikejdbc/ConnectionPool.scala)


<hr/>
### Global Settings
<hr/>

Configure global settings for SQL error logging, query inspection, and more:

```scala
object GlobalSettings {
  var loggingSQLErrors: Boolean
  var loggingSQLAndTime: LoggingSQLAndTimeSettings
  var sqlFormatter: SQLFormatterSettings
  var nameBindingSQLValidator: NameBindingSQLValidatorSettings
  var queryCompletionListener: (String, Seq[Any], Long) => Unit
  var queryFailureListener: (String, Seq[Any], Throwable) => Unit
}
```

Reference the [source code](https://github.com/scalikejdbc/scalikejdbc/blob/master/scalikejdbc-core/src/main/scala/scalikejdbc/GlobalSettings.scala) for more details.

<hr/>
### scalikejdbc-config
<hr/>

The `scalikejdbc-config` library simplifies the configuration process by utilizing Typesafe Config to read settings:

[Typesafe Config](https://github.com/lightbend/config)

To learn how to configure `scalikejdbc-config`, see setup page.

[/documentation/setup](/documentation/setup.html)

Configuration file should be like `src/main/resources/application.conf`. See Typesafe Config documentation in detail.

```
# JDBC settings
db.default.driver="org.h2.Driver"
db.default.url="jdbc:h2:file:./db/default"
db.default.user="sa"
db.default.password=""

# Connection Pool settings
db.default.poolInitialSize=5
db.default.poolMaxSize=7
# poolConnectionTimeoutMillis defines the amount of time a query will wait to acquire a connection
# before throwing an exception. This used to be called `connectionTimeoutMillis`. 
db.default.poolConnectionTimeoutMillis=1000
db.default.poolValidationQuery="select 1 as one"
db.default.poolFactoryName="commons-dbcp2"

db.legacy.driver="org.h2.Driver"
db.legacy.url="jdbc:h2:file:./db/db2"
db.legacy.user="foo"
db.legacy.password="bar"

# MySQL example
db.default.driver="com.mysql.jdbc.Driver"
db.default.url="jdbc:mysql://localhost/scalikejdbc"

# PostgreSQL example
db.default.driver="org.postgresql.Driver"
db.default.url="jdbc:postgresql://localhost:5432/scalikejdbc"
```

When setting up with `scalikejdbc.config.DBs.setupAll()`, the module automatically loads the specified JDBC drivers and prepares connection pools.

DBC drivers, once loaded, are globally available to the entire Java Virtual Machine (JVM). The selection process for a specific driver from the global list typically targets the first one capable of managing the given connection URL. This approach generally yields the correct behavior, except when multiple drivers capable of handling the same URL type (such as MySQL and MariaDB drivers, both supporting `jdbc:mysql:` URLs) are present in the classpath. In such cases, the expected driver might not be used, as the mere presence of JDBC drivers on the classpath often leads to their global registration, irrespective of their intended use.

```scala
import scalikejdbc._
import scalikejdbc.config._

// DBs.setup/DBs.setupAll loads specified JDBC driver classes.
DBs.setupAll()
// DBs.setup()
// DBs.setup("legacy")
// // Unlike DBs.setupAll(), DBs.setup() doesn't load configurations under global settings automatically
// DBs.loadGlobalSettings()

// loaded from "db.default.*"
val memberIds = DB readOnly { implicit session =>
  sql"select id from members".map(_.long(1)).list.apply()
}
// loaded from "db.legacy.*"
val legacyMemberIds = NamedDB("legacy") readOnly { implicit session =>
  sql"select id from members".map(_.long(1)).list.apply()
}

// wipes out ConnectionPool
DBs.closeAll()
```

<hr/>
### scalikejdbc-config with Environment
<hr/>

You can manage different configurations for multiple environments:

```
development.db.default.driver="org.h2.Driver"
development.db.default.url="jdbc:h2:file:./db/default"
development.db.default.user="sa"
development.db.default.password=""

prod {
  db {
    sandbox {
      driver="org.h2.Driver"
      url="jdbc:h2:file:./are-you-sure-in-production"
      user="user"
      password="pass"
    }
  }
}
```
To activate these settings, use `DBsWithEnv` instead of `DBs`.

```scala
DBsWithEnv("development").setupAll()
DBsWithEnv("prod").setup("sandbox")
```

<hr/>
### scalikejdbc-config for Global Settings
<hr/>

Global settings can be adjusted to log SQL errors, connection issues, and more:

```
# Global settings
scalikejdbc.global.loggingSQLErrors=true
scalikejdbc.global.loggingConnections=true
scalikejdbc.global.loggingSQLAndTime.enabled=true
scalikejdbc.global.loggingSQLAndTime.logLevel=info
scalikejdbc.global.loggingSQLAndTime.warningEnabled=true
scalikejdbc.global.loggingSQLAndTime.warningThresholdMillis=1000
scalikejdbc.global.loggingSQLAndTime.warningLogLevel=warn
scalikejdbc.global.loggingSQLAndTime.singleLineMode=false
scalikejdbc.global.loggingSQLAndTime.printUnprocessedStackTrace=false
scalikejdbc.global.loggingSQLAndTime.stackTraceDepth=10
```



