---
title: Operations - ScalikeJDBC
---

## Operations

<hr/>
### Query API
<hr/>

There are various query APIs. All of them (`single`, `first`, `list` and `foreach`) will execute `java.sql.PreparedStatement#executeQuery()`.

<hr/>
#### Single / Optional Result for Query
<hr/>

`single` returns matched single row as an `Option` value. If matched rows is not single, Exception will be thrown.

```java
import scalikejdbc._, SQLInterpolation._

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
  def apply(e: ResultName[Emp])(rs: WrappedResultSEt): Emp = 
    new Emp(id = rs.get(e.id), name = rs.get(e.name))
}
val e = Emp.syntax("e")
val emp: Option[Emp] = DB readOnly { implicit session =>
  withSQL { select.from(Emp as e).where.eq(e.id, id) }.map(Emp(e)).single.apply()
}
```

You can learn about QueryDSL in defail here: 

[/documentation/query-dsl](documentation/query-dsl.html)


<hr/>
#### First Result from Multiple Results
<hr/>

`first` returns the first row of matched rows as an `Option` value.

```java
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

```java
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

```java
DB readOnly { implicit session =>
  sql"select name from emp" foreach { rs => out.write(rs.string("name")) }
}

val e = Emp.syntax("e")
DB readOnly { implicit session =>
  withSQL { select(e.result.name).from(Emp as e) }.foreach { rs => out.write(rs.string(e.name)) }
}
```

<hr/>
### Update API
<hr/>

`update` executes `java.sql.PreparedStatement#executeUpdate()`.

```java
import scalikejdbc._, SQLInterpolation._

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

`execute` executes `java.sql.PreparedStatement#execute()`.

```java
DB autoCommit { implicit session =>
  sql"create table emp (id integer primary key, name varchar(30))".execute.apply()
}

// QueryDSL doesn't support DDL yet.
```

<hr/>
### Batch API
<hr/>

`batch` and `batchByName` executes `java.sql.PreparedStatement#executeBatch()`.

```java
import scalikejdbc._, SQLInterpolation._

DB localTx { implicit session =>
  val batchParams: Seq[Seq[Any]] = (2001 to 3000).map(i => Seq(i, "name" + i))
  sql"insert into emp (id, name) values (?, ?)".batch(batchParams: _*).apply()
}

val column = Emp.column
DB localTx { implicit session =>
  val batchParams: Seq[Seq[Any]] = (2001 to 3000).map(i => Seq(i, "name" + i))
  withSQL { 
    insert.into(Emp).namedValues(column.id -> sqls.?, column.name -> sqls.?)
  }.batch(batchParams: _*).apply()
}
```
