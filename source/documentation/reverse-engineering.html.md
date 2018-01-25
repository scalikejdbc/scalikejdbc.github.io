---
title: Reverse Engineering - ScalikeJDBC
---

## Reverse Engineering

<hr/>
### How to Setup
<hr/>

See [/documentation/setup](/documentation/setup.html).

<hr/>
### Sbt Command
<hr/>

```sh
sbt "scalikejdbcGen [table-name (class-name)]"
```

e.g.

```sh
sbt "scalikejdbcGen company"
sbt "scalikejdbcGen companies Company"
```

<hr/>
### Output Example
<hr/>

From the following table:

```sql
create table member (
  id int generated always as identity,
  name varchar(30) not null,
  description varchar(1000),
  birthday date,
  created_at timestamp not null,
  primary key(id)
)
```

This tool will generate the following Scala source code:

```scala
package models

import scalikejdbc._
import java.time.{LocalDate, ZonedDateTime}

case class Member(
  id: Int,
  name: String,
  description: Option[String] = None,
  birthday: Option[LocalDate] = None,
  createdAt: ZonedDateTime) {

  def save()(implicit session: DBSession = Member.autoSession): Member = Member.save(this)(session)

  def destroy()(implicit session: DBSession = Member.autoSession): Int = Member.destroy(this)(session)

}


object Member extends SQLSyntaxSupport[Member] {

  override val tableName = "MEMBER"

  override val columns = Seq("ID", "NAME", "DESCRIPTION", "BIRTHDAY", "CREATED_AT")

  def apply(m: SyntaxProvider[Member])(rs: WrappedResultSet): Member = apply(m.resultName)(rs)
  def apply(m: ResultName[Member])(rs: WrappedResultSet): Member = new Member(
    id = rs.get(m.id),
    name = rs.get(m.name),
    description = rs.get(m.description),
    birthday = rs.get(m.birthday),
    createdAt = rs.get(m.createdAt)
  )

  val m = Member.syntax("m")

  override val autoSession = AutoSession

  def find(id: Int)(implicit session: DBSession = autoSession): Option[Member] = {
    withSQL {
      select.from(Member as m).where.eq(m.id, id)
    }.map(Member(m.resultName)).single.apply()
  }

  def findAll()(implicit session: DBSession = autoSession): List[Member] = {
    withSQL(select.from(Member as m)).map(Member(m.resultName)).list.apply()
  }

  def countAll()(implicit session: DBSession = autoSession): Long = {
    withSQL(select(sqls.count).from(Member as m)).map(rs => rs.long(1)).single.apply().get
  }

  def findBy(where: SQLSyntax)(implicit session: DBSession = autoSession): Option[Member] = {
    withSQL {
      select.from(Member as m).where.append(where)
    }.map(Member(m.resultName)).single.apply()
  }

  def findAllBy(where: SQLSyntax)(implicit session: DBSession = autoSession): List[Member] = {
    withSQL {
      select.from(Member as m).where.append(where)
    }.map(Member(m.resultName)).list.apply()
  }

  def countBy(where: SQLSyntax)(implicit session: DBSession = autoSession): Long = {
    withSQL {
      select(sqls.count).from(Member as m).where.append(where)
    }.map(_.long(1)).single.apply().get
  }

  def create(
    name: String,
    description: Option[String] = None,
    birthday: Option[LocalDate] = None,
    createdAt: ZonedDateTime)(implicit session: DBSession = autoSession): Member = {
    val generatedKey = withSQL {
      insert.into(Member).namedValues(
        column.name -> name,
        column.description -> description,
        column.birthday -> birthday,
        column.createdAt -> createdAt
      )
    }.updateAndReturnGeneratedKey.apply()

    Member(
      id = generatedKey.toInt,
      name = name,
      description = description,
      birthday = birthday,
      createdAt = createdAt)
  }

  def batchInsert(entities: Seq[Member])(implicit session: DBSession = autoSession): List[Int] = {
    val params: Seq[Seq[(Symbol, Any)]] = entities.map(entity =>
      Seq(
        'name -> entity.name,
        'description -> entity.description,
        'birthday -> entity.birthday,
        'createdAt -> entity.createdAt))
    SQL("""insert into MEMBER(
      NAME,
      DESCRIPTION,
      BIRTHDAY,
      CREATED_AT
    ) values (
      {name},
      {description},
      {birthday},
      {createdAt}
    )""").batchByName(params: _*).apply[List]()
  }

  def save(entity: Member)(implicit session: DBSession = autoSession): Member = {
    withSQL {
      update(Member).set(
        column.id -> entity.id,
        column.name -> entity.name,
        column.description -> entity.description,
        column.birthday -> entity.birthday,
        column.createdAt -> entity.createdAt
      ).where.eq(column.id, entity.id)
    }.update.apply()
    entity
  }

  def destroy(entity: Member)(implicit session: DBSession = autoSession): Int = {
    withSQL { delete.from(Member).where.eq(column.id, entity.id) }.update.apply()
  }

}
```

And specs2 or ScalaTest's FlatSpec.


```scala
package models

import scalikejdbc.specs2.mutable.AutoRollback
import org.specs2.mutable._
import scalikejdbc._
import java.time.{LocalDate, ZonedDateTime}


class MemberSpec extends Specification {

  "Member" should {

    val m = Member.syntax("m")

    "find by primary keys" in new AutoRollback {
      val maybeFound = Member.find(123)
      maybeFound.isDefined should beTrue
    }
    "find by where clauses" in new AutoRollback {
      val maybeFound = Member.findBy(sqls.eq(m.id, 123))
      maybeFound.isDefined should beTrue
    }
    "find all records" in new AutoRollback {
      val allResults = Member.findAll()
      allResults.size should be_>(0)
    }
    "count all records" in new AutoRollback {
      val count = Member.countAll()
      count should be_>(0L)
    }
    "find all by where clauses" in new AutoRollback {
      val results = Member.findAllBy(sqls.eq(m.id, 123))
      results.size should be_>(0)
    }
    "count by where clauses" in new AutoRollback {
      val count = Member.countBy(sqls.eq(m.id, 123))
      count should be_>(0L)
    }
    "create new record" in new AutoRollback {
      val created = Member.create(name = "MyString", createdAt = null)
      created should not beNull
    }
    "save a record" in new AutoRollback {
      val entity = Member.findAll().head
      // TODO modify something
      val modified = entity
      val updated = Member.save(modified)
      updated should not equalTo(entity)
    }
    "destroy a record" in new AutoRollback {
      val entity = Member.findAll().head
      val deleted = Member.destroy(entity) == 1
      deleted should beTrue
      val shouldBeNone = Member.find(123)
      shouldBeNone.isDefined should beFalse
    }
    "perform batch insert" in new AutoRollback {
      val entities = Member.findAll()
      entities.foreach(e => Member.destroy(e))
      val batchInserted = Member.batchInsert(entities)
      batchInserted.size should be_>(0)
    }
  }

}
```
