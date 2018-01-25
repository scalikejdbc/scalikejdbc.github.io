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

case class Members(
  id: Int,
  name: String,
  description: Option[String] = None,
  birthday: Option[LocalDate] = None,
  createdAt: ZonedDateTime) {

  def save()(implicit session: DBSession = Members.autoSession): Members = Members.save(this)(session)

  def destroy()(implicit session: DBSession = Members.autoSession): Int = Members.destroy(this)(session)

}


object Members extends SQLSyntaxSupport[Members] {

  override val tableName = "MEMBERS"

  override val columns = Seq("ID", "NAME", "DESCRIPTION", "BIRTHDAY", "CREATED_AT")

  def apply(m: SyntaxProvider[Members])(rs: WrappedResultSet): Members = apply(m.resultName)(rs)
  def apply(m: ResultName[Members])(rs: WrappedResultSet): Members = new Members(
    id = rs.get(m.id),
    name = rs.get(m.name),
    description = rs.get(m.description),
    birthday = rs.get(m.birthday),
    createdAt = rs.get(m.createdAt)
  )

  val m = Members.syntax("m")

  override val autoSession = AutoSession

  def find(id: Int)(implicit session: DBSession = autoSession): Option[Members] = {
    withSQL {
      select.from(Members as m).where.eq(m.id, id)
    }.map(Members(m.resultName)).single.apply()
  }

  def findAll()(implicit session: DBSession = autoSession): List[Members] = {
    withSQL(select.from(Members as m)).map(Members(m.resultName)).list.apply()
  }

  def countAll()(implicit session: DBSession = autoSession): Long = {
    withSQL(select(sqls.count).from(Members as m)).map(rs => rs.long(1)).single.apply().get
  }

  def findBy(where: SQLSyntax)(implicit session: DBSession = autoSession): Option[Members] = {
    withSQL {
      select.from(Members as m).where.append(where)
    }.map(Members(m.resultName)).single.apply()
  }

  def findAllBy(where: SQLSyntax)(implicit session: DBSession = autoSession): List[Members] = {
    withSQL {
      select.from(Members as m).where.append(where)
    }.map(Members(m.resultName)).list.apply()
  }

  def countBy(where: SQLSyntax)(implicit session: DBSession = autoSession): Long = {
    withSQL {
      select(sqls.count).from(Members as m).where.append(where)
    }.map(_.long(1)).single.apply().get
  }

  def create(
    name: String,
    description: Option[String] = None,
    birthday: Option[LocalDate] = None,
    createdAt: ZonedDateTime)(implicit session: DBSession = autoSession): Members = {
    val generatedKey = withSQL {
      insert.into(Members).namedValues(
        column.name -> name,
        column.description -> description,
        column.birthday -> birthday,
        column.createdAt -> createdAt
      )
    }.updateAndReturnGeneratedKey.apply()

    Members(
      id = generatedKey.toInt,
      name = name,
      description = description,
      birthday = birthday,
      createdAt = createdAt)
  }

  def batchInsert(entities: Seq[Members])(implicit session: DBSession = autoSession): List[Int] = {
    val params: Seq[Seq[(Symbol, Any)]] = entities.map(entity =>
      Seq(
        'name -> entity.name,
        'description -> entity.description,
        'birthday -> entity.birthday,
        'createdAt -> entity.createdAt))
    SQL("""insert into MEMBERS(
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

  def save(entity: Members)(implicit session: DBSession = autoSession): Members = {
    withSQL {
      update(Members).set(
        column.id -> entity.id,
        column.name -> entity.name,
        column.description -> entity.description,
        column.birthday -> entity.birthday,
        column.createdAt -> entity.createdAt
      ).where.eq(column.id, entity.id)
    }.update.apply()
    entity
  }

  def destroy(entity: Members)(implicit session: DBSession = autoSession): Int = {
    withSQL { delete.from(Members).where.eq(column.id, entity.id) }.update.apply()
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


class MembersSpec extends Specification {

  "Members" should {

    val m = Members.syntax("m")

    "find by primary keys" in new AutoRollback {
      val maybeFound = Members.find(123)
      maybeFound.isDefined should beTrue
    }
    "find by where clauses" in new AutoRollback {
      val maybeFound = Members.findBy(sqls.eq(m.id, 123))
      maybeFound.isDefined should beTrue
    }
    "find all records" in new AutoRollback {
      val allResults = Members.findAll()
      allResults.size should be_>(0)
    }
    "count all records" in new AutoRollback {
      val count = Members.countAll()
      count should be_>(0L)
    }
    "find all by where clauses" in new AutoRollback {
      val results = Members.findAllBy(sqls.eq(m.id, 123))
      results.size should be_>(0)
    }
    "count by where clauses" in new AutoRollback {
      val count = Members.countBy(sqls.eq(m.id, 123))
      count should be_>(0L)
    }
    "create new record" in new AutoRollback {
      val created = Members.create(name = "MyString", createdAt = null)
      created should not beNull
    }
    "save a record" in new AutoRollback {
      val entity = Members.findAll().head
      // TODO modify something
      val modified = entity
      val updated = Members.save(modified)
      updated should not equalTo(entity)
    }
    "destroy a record" in new AutoRollback {
      val entity = Members.findAll().head
      val deleted = Members.destroy(entity) == 1
      deleted should beTrue
      val shouldBeNone = Members.find(123)
      shouldBeNone.isDefined should beFalse
    }
    "perform batch insert" in new AutoRollback {
      val entities = Members.findAll()
      entities.foreach(e => Members.destroy(e))
      val batchInserted = Members.batchInsert(entities)
      batchInserted.size should be_>(0)
    }
  }

}
```
