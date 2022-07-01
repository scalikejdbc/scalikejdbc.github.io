---
title: Auto Session - ScalikeJDBC
---

## Auto Session

<hr/>
### Why AutoSession?
<hr/>

Basic usage of ScalikeJDBC is using `DB.autoCommit/readOnly/localTx/withinTx { ...}` blocks.

However, if you'd like to re-use methods, they might not be available.

```scala
def findById(id: Long) = DB readOnly {
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
}
```

When you use the above method in a transaction block, the code won't work as you expected.

The reason is that since `#findById(Long)` uses another session(=connection), it couldn't access uncommitted data.

```scala
DB localTx { implicit session =>
  val id = create("Alice")
  findById(id) // Not found!
}
```

You need to change method's API to accept implicit parameters and now you don't need `DB` block inside the method.

```scala
def findById(id: Long)(implicit session: DBSession) =
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
```

This one works as expected.

```scala
DB localTx { implicit session =>
  val id = create("Alice")
  findById(id) // Found!
}
```

But unfortunately, now we need to pass implicit parameter to `#findById` every time to use it.

```scala
// now we cannot use this method directly
findById(id) // implicit parameter not found!

DB readOnly { implicit session => findById(id) }
```

`AutoSession` is a solution for this issue. Use `AutoSession` as default value of the implicit parameter.

```scala
def findById(id: Long)(implicit session: DBSession = AutoSession) =
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
```

This change made `#findById` flexible.

```scala
findById(id) // borrows a read-only session and gives it back
DB localTx { implicit session => findById(id) } // using implicit session
```

If you do the same with `NamedDB`, use `NamedAutoSession` as follows.

```scala
def findById(id: Long)(implicit session: DBSession = NamedAutoSession("named")) =
  sql"select id, name from members where id = ${id}"
```

<hr/>
### ReadOnlyAutoSession
<hr/>

Since version 1.7.4, `ReadOnlyAutoSession` and `NamedReadOnlyAutoSession` is also available. 

These auto sessions disallow update/execute operations.


