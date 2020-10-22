---
title: Transaction - ScalikeJDBC
---

## Transaction

<hr/>
### #readOnly block / session
<hr/>

Executes query in read-only mode.

```scala
val names = DB readOnly { implicit session =>
  sql"select name from emp".map { rs => rs.string("name") }.list.apply()
}

implicit val session = DB.readOnlySession
try {
  val names = sql"select name from emp".map { rs => rs.string("name") }.list.apply()
  // do something
} finally {
  session.close()
}
```

Of course, `update` operations in read-only mode will cause `java.sql.SQLException`.

```scala
DB readOnly { implicit session =>
  sql"update emp set name = ${name} where id = ${id}".update.apply()
} // will throw java.sql.SQLException
```

<hr/>
### #autoCommit block / session
<hr/>

Executes query / update in auto-commit mode.

```scala
val count = DB autoCommit { implicit session =>
  sql"update emp set name = ${name} where id = ${id}".update.apply()
}
```

When using autoCommitSession, every operation will be executed in auto-commit mode.

```scala
implicit val session = DB.autoCommitSession
try {
  sql"update emp set name = ${name1} where id = ${id1}".update.apply() // auto-commit
  sql"update emp set name = ${name2} where id = ${id2}".update.apply() // auto-commit
} finally { session.close() }
```

<hr/>
### #localTx block
<hr/>

Executes query / update in block-scoped transactions.

If an Exception was thrown in the block, the transaction will perform rollback automatically.

```scala
val count = DB localTx { implicit session =>
  // --- transcation scope start ---
  sql"update emp set name = ${name1} where id = ${id1}".update.apply()
  sql"update emp set name = ${name2} where id = ${id2}".update.apply()
  // --- transaction scope end ---
}
```

`TxBoundary` provides other transaction boundary instead of Exception as follows (2.2.0 or higher):

```scala
import scalikejdbc._
import scala.util.Try
import scalikejdbc.TxBoundary.Try._

val result: Try[Result] = DB localTx { implicit session =>
  Try { doSomeStaff() }
}
// localTx rolls back when `result` is `Failure`
// http://scala-lang.org/api/current/#scala.util.Try
```

Built-in type class instances are `Try`, `Either` and `Future`. You can use them by `import scalikejdbc.TxBoundary,***._`.

<hr/>
### #futureLocalTx block 
<hr/>

`futureLocalTx` use `Future`'s state as transaction boundary. If one of the Future operations was failed, the transaction will perform rollback automatically. 

```scala
object FutureDB {
  implicit val ec = myOwnExecutorContext
  def updateFirstName(id: Int, firstName: String)(implicit session: DBSession): Future[Int] = {
    Future { 
      blocking {
        session.update("update users set first_name = ? where id = ?", firstName, id)
      } 
    }
  }
  def updateLastName(id: Int, lastName: String)(implicit session: DBSession): Future[Int] = {
    Future { 
      blocking {
        session.update("update users set last_name = ? where id = ?", lastName, id)
      } 
    }
  }
}

object Example {
  import FutureDB._
  val fResult = DB futureLocalTx { implicit s =>  
    updateFirstName(3, "John").map(_ => updateLastName(3, "Smith"))
  }
}

Example.fResult.foreach(println(_))
// #=> 1
````

or `TxBoundary[Future[A]]` is also available.

```scala
import scalikejdbc.TxBoundary.Future._
val fResult = DB localTx { implicit s =>  
  updateFirstName(3, "John").map(_ => updateLastName(3, "Smith"))
}
```

<hr/>
### #Working with IO monads
<hr/>

<hr/>
#### IO monads minimal example
<hr/>

*MyIO*

```scala
sealed abstract class MyIO[+A] {
  import MyIO._

  def flatMap[B](f: A => MyIO[B]): MyIO[B] = {
    this match {
      case Delay(thunk) => Delay(() => f(thunk()).run())
    }
  }

  def map[B](f: A => B): MyIO[B] = flatMap(x => MyIO(f(x)))

  def run(): A = {
    this match {
      case Delay(f) => f.apply()
    }
  }

  def attempt: MyIO[Either[Throwable, A]] =
    MyIO(try {
      Right(run())
    } catch {
      case scala.util.control.NonFatal(t) => Left(t)
    })

}

object MyIO {
  def apply[A](a: => A): MyIO[A] = Delay(() => a)

  final case class Delay[+A](thunk: () => A) extends MyIO[A]
}
```


*TxBoundary typeclass instance for MyIO[A]*

```scala
import scalikejdbc._

implicit def myIOTxBoundary[A]: TxBoundary[MyIO[A]] = new TxBoundary[MyIO[A]] {

  def finishTx(result: MyIO[A], tx: Tx): MyIO[A] = {
    result.attempt.flatMap {
      case Right(a) => MyIO(tx.commit()).flatMap(_ => MyIO(a))
      case Left(e) => MyIO(tx.rollback()).flatMap(_ => MyIO(throw e))
    }
  }

  override def closeConnection(result: MyIO[A], doClose: () => Unit): MyIO[A] = {
    for {
      x <- result.attempt
      _ <- MyIO(doClose())
      a <- MyIO(x.fold(throw _, identity))
    } yield a
  }
}
```


*localTx*

To use `scalikejdbc` with IO monads, you cannot use `localTx` out of the box.
You must use it with a `TxBoundary` instance for MyIO[A]

```scala
import scalikejdbc._

type A = ???

def asyncExecution[A]: DBSession => MyIO[A] = ???

// default
DB.localTx(asyncExecution)(boundary = myIOTxBoundary)

// named
NamedDB('named).localTx(asyncExecution)(boundary = myIOTxBoundary)

```

<hr/>
### #withinTx block / session
<hr/>

Executes query / update in already existing transactions.

In this case, all the transactional operations (such as `Tx#begin()`, `Tx#rollback()` or `Tx#commit()`) should be managed by users of ScalikeJDBC.

```scala
val db = DB(conn)
try {
  db.begin()
  val names = db withinTx { implicit session =>
    // if a transaction has not been started, IllegalStateException will be thrown
    sql"select name from emp".map { rs => rs.string("name") }.list.apply()
  }
  db.rollback() // it might throw Exception
} finally { db.close() }

val db = DB(conn)
try {
  db.begin()
  implicit val session = db.withinTxSession()
  val names = sql"select name from emp".map { rs => rs.string("name") }.list.apply()
  db.rollbackIfActive() // it NEVER throws Exception
} finally { db.close() }
```


