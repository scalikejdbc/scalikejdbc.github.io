---
title: FAQ - ScalikeJDBC
---

## FAQ


<hr/>
### Oracle DB / MS SQLServer supported?
<hr/>

ScalikeJDBC supports PostgreSQL, MySQL, H2 Database Engine and HSQLDB. We never release without passing all the unit tests with these RDBMS. If you're using either of them, ScalikeJDBC should be very stable.

On the other hand, ScalikeJDBC simply uses JDBC drivers internally, so it basically should work fine with any other RDBMS. 

<hr/>
### How to use other connection pool?
<hr/>

ScalikeJDBC's default connection pool implementation is [Apache Commons DBCP](http://commons.apache.org/proper/commons-dbcp/). 

You can easily use other implementation. See in detail:

[/documentation/connection-pool.html](/documentation/connection-pool.html)

<hr/>
### How to share same DB with Rails ActiveRecord?
<hr/>

As you know, Rails ActiveRecord saves timestamp values in UTC time zone. DB column types will be `timetamp without timezone`.

When you need to work with them, call the following Java TimeZone's setter method (instead of `DateTimeZone.setDefault(DateTimeZone.UTC)`) at first.

```scala
java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("UTC"))
```

<hr/>
### non-blocking support?
<hr/>

Unfortunately, no. Indeed, JDBC drivers block on socket IO. So using them to talk with RDBMS in async event driven architecture may not be appropriate. However, actually most of real world applications don’t need event-driven architecture yet. JDBC is still important infrastructure for apps on the JVM.

If you really prefer non-blocking database access, take a look at ScalikeJDBC-Async. It provides non-blocking APIs to talk with PostgreSQL and MySQL in the JDBC way.

https://github.com/scalikejdbc/scalikejdbc-async

ScalikeJDBC-Async is still in the alpha stage. If you don’t have motivation to investigate or fix issues by yourself, we recommend you waiting until stable version release someday.

<hr/>
### ORM feature?
<hr/>

ScalikeJDBC's concept is a tidy wrapper of JDBC drivers, so it handles very lower layer than common ORMs. If you're looking for an ORM which supports associations or other rich features, take a look at Skinny ORM.

Skinny ORM is the default DB access library of [Skinny Framework](http://skinny-framework.org/). Skinny ORM is built upon ScalikeJDBC. In most cases, it will make things easier.

http://skinny-framework.org/documentation/orm.html

<hr/>
### Is it possible to integrate with Play Framework?
<hr/>

Yes, it is. We support some Play plugins to seamlesssly integrate ScalikeJDBC with Play Framework. 

See in detail here: [/documentation/playframework-support.html](/documentation/playframework-support.html)

<hr/>
### License?
<hr/>

the Apache License, Version 2.0

https://github.com/scalikejdbc/scalikejdbc/blob/develop/LICENSE.txt


