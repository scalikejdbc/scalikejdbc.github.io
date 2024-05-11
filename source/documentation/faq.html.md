---
title: FAQ - ScalikeJDBC
---

## FAQ


<hr/>
### Oracle DB / MS SQLServer supported?
<hr/>

ScalikeJDBC primarily supports PostgreSQL, MySQL, H2 Database Engine, and HSQLDB. We ensure the reliability for production-grade operations by never releasing versions that have not passed all the unit tests with these RDBMS. However, since ScalikeJDBC uses standard JDBC drivers internally, it should generally work well with any other RDBMS.

<hr/>
### How to use other connection pool?
<hr/>

The default connection pool in ScalikeJDBC is [Apache Commons DBCP](https://commons.apache.org/proper/commons-dbcp/).

For instructions on using alternative connection pool implementations, please visit [/documentation/connection-pool.html](/documentation/connection-pool.html) for details.

<hr/>
### How to share same DB with Rails ActiveRecord?
<hr/>

As you may know, Rails ActiveRecord stores timestamp values in UTC time zone without timezone information. In other words, those DB column types are usually `timetamp without timezone`. To align Scala applications with this format, set the Java TimeZone globally at startup:

```scala
java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("UTC"))
```

<hr/>
### How to build a like condition part?
<hr/>

For SQL LIKE conditions, use the `scalikejdbc.LikeConditionEscapeUtil` utility to handle special characters effectively:

```scala
LikeConditionEscapeUtil.escape("foo%aa_bbb\\ccc")     // "foo\\%aa\\_bbb\\\\ccc"
LikeConditionEscapeUtil.beginsWith("foo%aa_bbb\\ccc") // "foo\\%aa\\_bbb\\\\ccc%"
LikeConditionEscapeUtil.endsWith("foo%aa_bbb\\ccc")   // "%foo\\%aa\\_bbb\\\\ccc"
LikeConditionEscapeUtil.contains("foo%aa_bbb\\ccc")   // "%foo\\%aa\\_bbb\\\\ccc%"
```

<hr/>
### Non-blocking support?
<hr/>

ScalikeJDBC does not currently offer non-blocking support, as JDBC inherently blocks on socket IO. For apps requiring non-blocking database interactions, consider using ScalikeJDBC-Async, which offers non-blocking APIs for PostgreSQL and MySQL.

https://github.com/scalikejdbc/scalikejdbc-async

ScalikeJDBC-Async is currently in the alpha stage. If you are not prepared to actively investigate and resolve issues, it may be advisable to wait for the release of a stable version in the future.

<hr/>
### Is it possible to integrate with Play Framework?
<hr/>

ScalikeJDBC can be integrated with the Play Framework through specific plugins, enhancing its functionality within Play applications.

See in detail here: [/documentation/playframework-support.html](/documentation/playframework-support.html)

<hr/>
### License?
<hr/>

ScalikeJDBC is licensed under the Apache License, Version 2.0.

https://github.com/scalikejdbc/scalikejdbc/blob/master/LICENSE.txt
