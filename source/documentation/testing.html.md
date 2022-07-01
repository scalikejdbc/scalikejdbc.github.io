---
title: Testing - ScalikeJDBC
---

## Testing

<hr/>
### Setup
<hr/>

See [/documentation/setup](/documentation/setup.html).

<hr/>
### For ScalaTest Users
<hr/>

`AutoRollback` trait provides automatic rollback after each test and data fixture. 

NOTICE: scalikejdbc-test is compatible with ScalaTest 2.0 or higher.

```scala
import scalikejdbc._
import scalikejdbc.scalatest.AutoRollback
import org.scalatest.fixture.FlatSpec

class AutoRollbackSpec extends FlatSpec with AutoRollback {

  // override def db = NamedDB("anotherdb").toDB

  override def fixture(implicit session: DBSession) {
    sql"insert into members values (1, ${"Alice"}, current_timestamp)".update.apply()
    sql"insert into members values (2, ${"Bob"}, current_timestamp)".update.apply()
  }

  behavior of "Members"

  it should "create a new record" in { implicit session =>
    val before = Member.count()
    Member.create(3, "Chris")
    Member.count() should equal(before + 1)
  }

}
```

<hr/>
### For specs2 Users
<hr/>

`AutoRollback` trait provides automatic rollback after each test and data fixture.

<hr/>
#### unit style
<hr/>

```scala
import scalikejdbc._
import scalikejdbc.specs2.mutable.AutoRollback
import org.specs2.mutable.Specification

object MemberSpec extends Specification {

  sequential

  "Member should create a new record" in new AutoRollback {
    val before = Member.count()
    Member.create(3, "Chris")
    Member.count() must_==(before + 1)
  }

  "Member should ... " in new AutoRollbackWithFixture {
    ...
  }

}

trait AutoRollbackWithFixture extends AutoRollback {
  // override def db = NamedDB("db2").toDB
  override def fixture(implicit session: DBSession) {
    sql"insert into members values (1, ${"Alice"}, current_timestamp)".update.apply()
    sql"insert into members values (2, ${"Bob"}, current_timestamp)".update.apply()
  }
}

```

<hr/>
#### acceptance style
<hr/>

```scala
import scalikejdbc._
import scalikejdbc.specs2.AutoRollback
import org.specs2.Specification

class MemberSpec extends Specification { def is =

  args(sequential = true) ^
  "Member should create a new record" ! autoRollback().create
  end

  case class autoRollback() extends AutoRollback {

    // override def db = NamedDB("db2").toDB
    // override def fixture(implicit session: DBSession) { ... }

    def create = this {
      val before = Member.count()
      Member.create(3, "Chris")
      Member.count() must_==(before + 1)
    }
  }

}
```
