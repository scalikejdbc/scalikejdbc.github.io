---
title: Operations - ScalikeJDBC
---

## Operations

<hr/>
### Query API
<hr/>

There are various query APIs. All of them (`single`, `first`, `list` and `foreach`) will execute `scala.sql.PreparedStatement#executeQuery()`.

<hr/>
#### Single / Optional Result for Query
<hr/>

`single` returns matched single row as an `Option` value. If matched rows is not single, Exception will be thrown.

```scala
import scalikejdbc._

val id = 123

// simple example
val name: Option[String] = DB readOnly { implicit session =>
  sql"select name from emp where id = ${id}".map(rs => rs.string("name")).single.apply()
}

// defined mapper as a function
val nameOnly = (rs: WrappedResultSet) => rs.string("name")
val name: Option[String] = DB readOnly { implicit session =>
  sql"select name from emp where id = ${id}".map(nameOnly).single.apply()
}

// define a class to map the result
case class Emp(id: String, name: String)
val emp: Option[Emp] = DB readOnly { implicit session =>
  sql"select id, name from emp where id = ${id}"
    .map(rs => Emp(rs.string("id"), rs.string("name"))).single.apply()
}

// QueryDSL
object Emp extends SQLSyntaxSupport[Emp] {
  def apply(e: ResultName[Emp])(rs: WrappedResultSet): Emp =
    new Emp(id = rs.get(e.id), name = rs.get(e.name))
}
val e = Emp.syntax("e")
val emp: Option[Emp] = DB readOnly { implicit session =>
  withSQL { select.from(Emp as e).where.eq(e.id, id) }.map(Emp(e)).single.apply()
}
```

You can learn about QueryDSL in defail here:

[/documentation/query-dsl](/documentation/query-dsl.html)


<hr/>
#### First Result from Multiple Results
<hr/>

`first` returns the first row of matched rows as an `Option` value.

```scala
val name: Option[String] = DB readOnly { implicit session =>
  sql"select name from emp".map(rs => rs.string("name")).first.apply()
}

val e = Emp.syntax("e")
val name: Option[String] = DB readOnly { implicit session =>
  withSQL { select(e.result.name).from(Emp as e) }.map(_.string(e.name)).first.apply()
}
```

<hr/>
#### List Results
<hr/>

`list` returns matched multiple rows as `scala.collection.immutable.List`.

```scala
val name: List[String] = DB readOnly { implicit session =>
  sql"select name from emp".map(rs => rs.string("name")).list.apply()
}

val e = Emp.syntax("e")
val name: Option[String] = DB readOnly { implicit session =>
  withSQL { select(e.result.name).from(Emp as e) }.map(_.string(e.name)).list.apply()
}
```

<hr/>
#### Foreach Operation
<hr/>

`foreach` allows you to make some side-effect in iterations. This API is useful for handling large `ResultSet`.

```scala
DB readOnly { implicit session =>
  sql"select name from emp".foreach { rs => 
    out.write(rs.string("name")) 
  }
}

val e = Emp.syntax("e")
DB readOnly { implicit session =>
  withSQL { select(e.name).from(Emp as e) }.foreach { rs => 
    out.write(rs.string(e.name)) 
  }
}
```

<hr/>
#### Setting JDBC fetchSize
<hr/>

For instance, the PostgreSQL JDBC driver does infinite(!) caching for result sets if fetchSize is set to 0 (the default) and this causes memory problems.

http://docs.oracle.com/javase/8/docs/api/java/sql/Statement.html#setFetchSize-int-

You can specify JDBC fetchSize as follows since version 2.0.5.

```scala
val e = Emp.syntax("e")
DB readOnly { implicit session =>
  sql"select name from emp"
    .fetchSize(1000)
    .foreach { rs => out.write(rs.string("name")) }
}
```

Or it's also fine to set fetchSize to `scalikejdbc.DBSession`.

```scala
val (e, c) = (Emp.syntax("e"), Cmp.syntax("c"))

DB readOnly { implicit session =>
  session.fetchSize(1000)

  withSQL { select(e.name).from(Emp as e) }.foreach { rs => 
    out.write(rs.string(e.name) 
  }
  withSQL { select(c.name).from(Cmp as c) }.foreach { rs => 
    out.write(rs.string(c.name)) 
  }
}
```

<hr/>
#### Implementing Custom Extractor
<hr/>

In some cases you might want to implement a custom extractor. This can be useful for testing out queries.

This example shows how to preserve ``null`` values in a result set.

```scala
def toMap(rs: WrappedResultSet): Map[String, Any] =  {
  (1 to rs.metaData.getColumnCount).foldLeft(Map[String, Any]()) { (result, i) =>
    val label = rs.metaData.getColumnLabel(i)
    Some(rs.any(label)).map { nullableValue => result + (label -> nullableValue) }.getOrElse(result)
  }
}

sql"select * from emp".map(rs => toMap(rs)).single.apply()
```


<hr/>
### Update API
<hr/>

`update` executes `scala.sql.PreparedStatement#executeUpdate()`.

```scala
import scalikejdbc._

DB localTx { implicit session =>
  sql"""insert into emp (id, name, created_at) values (${id}, ${name}, ${DateTime.now})"""
    .update.apply()
  val id = sql"insert into emp (name, created_at) values (${name}, current_timestamp)"
    .updateAndReturnGeneratedKey.apply()
  sql"update emp set name = ${newName} where id = ${id}".update.apply()
  sql"delete emp where id = ${id}".update.apply()
}

val column = Emp.column
DB localTx { implicit s =>
  withSQL {
    insert.into(Emp).namedValues(
      column.id -> id,
      column.name -> name,
      column.createdAt -> DateTime.now)
   }.update.apply()

  val id: Long = withSQL {
    insert.into(Empy).namedValues(column.name -> name, column.createdAt -> sqls.currentTimestamp)
  }.updateAndReturnGeneratedKey.apply()

  withSQL { update(Emp).set(column.name -> newName).where.eq(column.id, id) }.update.apply()
  withSQL { delete.from(Emp).where.eq(column.id, id) }.update.apply()
}

```

<hr/>
### Execute API
<hr/>

`execute` executes `scala.sql.PreparedStatement#execute()`.

```scala
DB autoCommit { implicit session =>
  sql"create table emp (id integer primary key, name varchar(30))".execute.apply()
}

// QueryDSL doesn't support DDL yet.
```

<hr/>
### Batch API
<hr/>

`batch` and `batchByName` executes `scala.sql.PreparedStatement#executeBatch()`.

```scala
import scalikejdbc._

DB localTx { implicit session =>
  val batchParams: Seq[Seq[Any]] = (2001 to 3000).map(i => Seq(i, "name" + i))
  sql"insert into emp (id, name) values (?, ?)".batch(batchParams: _*).apply()
}

DB localTx { implicit session =>
  sql"insert into emp (id, name) values ({id}, {name})"
    .batchByName(Seq(Seq('id -> 1, 'name -> "Alice"), Seq('id -> 2, 'name -> "Bob")):_*)
    .apply()
}

val column = Emp.column
DB localTx { implicit session =>
  val batchParams: Seq[Seq[Any]] = (2001 to 3000).map(i => Seq(i, "name" + i))
  withSQL {
    insert.into(Emp).namedValues(column.id -> sqls.?, column.name -> sqls.?)
  }.batch(batchParams: _*).apply()
}
```
