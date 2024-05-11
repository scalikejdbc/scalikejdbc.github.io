---
title: Transaction - ScalikeJDBC
---

## Transaction

<hr/>
### #readOnly block / session
<hr/>

This code block executes queries in read-only mode. This means that no update/execute operations are allowed.

```scala
val names = DB readOnly { implicit session =>
  sql"select name from emp".map { rs => rs.string("name") }.list.apply()
}

// Alternatively, you can use a session variable this way:
implicit val session = DB.readOnlySession
try {
  val names = sql"select name from emp".map { rs => rs.string("name") }.list.apply()
  // do something
} finally {
  session.close()
}
```

If you run an `update` operation within read-only mode, the code throws `java.sql.SQLException`:

```scala
DB readOnly { implicit session =>
  sql"update emp set name = ${name} where id = ${id}".update.apply()
} // will throw java.sql.SQLException
```

<hr/>
### #autoCommit block / session
<hr/>

This code block executes queries / update operations in auto-commit mode.

```scala
val count = DB autoCommit { implicit session =>
  sql"update emp set name = ${name} where id = ${id}".update.apply()
}
```

When using `autoCommitSession`, an operation will be executed in auto-commit mode too.

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

This code block executes queries / update operations in block-scoped transactions. When an Exception was thrown within the block, the ongoing transaction will be cancelled and then the transaction will be rolled back automatically.

```scala
val count = DB localTx { implicit session =>
  // --- transcation scope start ---
  sql"update emp set name = ${name1} where id = ${id1}".update.apply()
  sql"update emp set name = ${name2} where id = ${id2}".update.apply()
  // --- transaction scope end ---
}
```

The `TxBoundary` class provides a differnt transaction boundary beyond throwing an Exception (This feature is available since version 2.2.0):

```scala
import scalikejdbc._
import scala.util.Try
import scalikejdbc.TxBoundary.Try._

val result: Try[Result] = DB localTx { implicit session =>
  Try { doSomeStaff() }
}
// localTx rolls back when `result` is `Failure`
// https://www.scala-lang.org/api/current/scala/util/Try.html
```

The Built-in type class instances are `Try`, `Either` and `Future`. You can use them by having `import scalikejdbc.TxBoundary,***._` in your code.

<hr/>
### #futureLocalTx block 
<hr/>

The `futureLocalTx` block uses `Future`'s state as the transaction boundary. When any of the `Future` operations fails, the transaction will be rolled back automatically. 

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
    updateFirstName(3, "John").flatMap(_ => updateLastName(3, "Smith"))
  }
}

Example.fResult.foreach(println(_))
// #=> 1
````

Alternatively, you can use `TxBoundary[Future[A]]` too:

```scala
import scalikejdbc.TxBoundary.Future._
val fResult = DB localTx { implicit s =>  
  updateFirstName(3, "John").flatMap(_ => updateLastName(3, "Smith"))
}
```

<hr/>
### Working with IO monads
<hr/>

This section guides you on how to implement a transaction boundary for IO monads.

<hr/>
#### IO monad minimal example
<hr/>

Let's say you have a custom IO monad called `MyIO`:

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
Here is an example of `TxBoundary` typeclass instance for `MyIO[A]` type:

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

Woth the above custom `TxBoundary`, you can use `localTx` code blocks in a simple way sa below:

```scala
import scalikejdbc._
type A = ???
def asyncExecution: DBSession => MyIO[A] = ???
// default
DB.localTx(asyncExecution)(boundary = myIOTxBoundary)
// named
NamedDB("named").localTx(asyncExecution)(boundary = myIOTxBoundary)
```

<hr/>
#### Cats Effect IO example
<hr/>

This section guides on how to define your own custom `TxBoundary` typeclass instance for `cats.effect.IO[A]`.

`cats.effect.IO` offers two ways to handle completion/cancellation as below. You can use `guaranteeCase` for commit/rollback operations while going with `guarantee` for connection closure.

```scala
import scalikejdbc._
import cats.effect._

implicit def catsEffectIOTxBoundary[A]: TxBoundary[IO[A]] = new TxBoundary[IO[A]] {
  def finishTx(result: IO[A], tx: Tx): IO[A] =
    result.guaranteeCase {
      case ExitCase.Completed => IO(tx.commit())
      case _ => IO(tx.rollback())
    }

  override def closeConnection(result: IO[A], doClose: () => Unit): IO[A] =
    result.guarantee(IO(doClose()))
}
```

To take control of all the side-effects that happen within a `localTx` code block, you can use `suspend` method to wrap the code blocks using `localTx`:

```scala
import scalikejdbc._
import cats.effect._

type A = ???

def ioExecution: DBSession => IO[A] = ???

// default
IO.suspend {
  DB.localTx(ioExecution)(boundary = catsEffectIOTxBoundary)
}

// named
IO.suspend {
  NamedDB("named").localTx(ioExecution)(boundary = catsEffectIOTxBoundary)
}

```

<hr/>
### #withinTx block / session
<hr/>

This code block joins an exsting transcation and executes queries / update operations with it.

In this case, your code is responsible to manage all transactional operations (such as `Tx#begin()`, `Tx#rollback()` or `Tx#commit()`). ScalikeJDBC never does anything under the hood.

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
