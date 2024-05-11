---
title: Auto Session - ScalikeJDBC
---

## Auto Session

<hr/>
### Why AutoSession?
<hr/>

Typically, ScalikeJDBC operations are encapsulated within `DB.autoCommit`, `DB.readOnly`, and other transaction blocks. For reusing methods across different transaction contexts as below, 

```scala
def findById(id: Long) = DB readOnly {
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
}
```

`AutoSession` becomes essential. In a transaction block, this method may not perform as expected because it uses a separate session and cannot access uncommitted data. The reason is that since `#findById(Long)` uses another session(=connection), it couldn't access uncommitted data.

```scala
DB localTx { implicit session =>
  val id = create("Alice")
  findById(id) // Not found!
}
```

With this change, the method can access the current transaction context. Instead of having `DB` blocks inside, your method can accept an implict DBSession paramter from external code to join an existing transactional session.

```scala
def findById(id: Long)(implicit session: DBSession) =
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
```

With the change, the following code works as you expect.

```scala
DB localTx { implicit session =>
  val id = create("Alice")
  findById(id) // Found!
}
```

But unfortunately, now that we need to pass implicit parameter to `#findById` every time to use the method, it could be troublesome especially for simple code snippets.

```scala
// now we cannot use this method directly
findById(id) // implicit parameter not found!

DB readOnly { implicit session => findById(id) }
```

`AutoSession` is a solution for the issue. You can have `AutoSession` as default value of the implicit parameter.

```scala
def findById(id: Long)(implicit session: DBSession = AutoSession) =
  sql"select id, name from members where id = ${id}"
    .map(rs => Member(rs)).single.apply()
```

Having the default implement value can make `#findById` even more flexible plus much simpler.

```scala
findById(id) // borrows a read-only session and gives it back
DB localTx { implicit session => findById(id) } // using implicit session
```

When you do the same with `NamedDB`, you can use `NamedAutoSession` as below:

```scala
def findById(id: Long)(implicit session: DBSession = NamedAutoSession("named")) =
  sql"select id, name from members where id = ${id}"
```

<hr/>
### ReadOnlyAutoSession
<hr/>

Since version 1.7.4, `ReadOnlyAutoSession` and `NamedReadOnlyAutoSession` is also available, which are tailored for read-only operations, preventing any update or execute operations.

