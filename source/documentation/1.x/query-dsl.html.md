---
title: QueryDSL - ScalikeJDBC
---

## QueryDSL

<hr/>
### Introduction
<hr/>

Since version 1.6.0, Query DSL is newly added. It's much readable and type-safe DSL.

```scala
val id = 123
val (m, g) = (GroupMember.syntax("m"), Group.syntax("g"))
val groupMember = sql"""
  select
    ${m.result.*}, ${g.result.*}
  from
    ${GroupMember.as(m)} left join ${Group.as(g)} on ${m.groupId} = ${g.id}
  where
    ${m.id} = ${id}
  """
    .map(GroupMember(m, g)).single.apply()
```

You can re-write this SQLInterpolation code by using QueryDSL as follow.

We believe this code is much simpler and quite understandable.

```scala
val id = 123
val (m, g) = (GroupMember.syntax("m"), Group.syntax("g"))
val groupMember = withSQL {
  select.from(GroupMember as m).leftJoin(Group as g).on(m.groupId, g.id)
    .where.eq(m.id, id)
}.map(GroupMember(m, g)).single.apply()
```

More examples are

```scala
val m = Member.syntax("m")
val ids: List[Long] = sql"select ${m.result.id} from ${Member.as(m)} where ${m.gourpId} = 1"
val members = sql"select ${m.result.*} from ${Member.as(m)}".map(Member(m)).list.apply()
```

will be like this:

```scala
val m = Member.syntax("m")
val ids: List[Long] = withSQL { select(m.result.id).from(Member as m).where.eq(m.groupId, 1) }
  .map(rs => rs.long(m.resultName.id)).list.apply()
val members = withSQL { select.from(Member as m) }.map(Member(m)).list.apply()
// or select.all(m).from(Member as m)
```

<hr/>
### QueryDSL Reference
<hr/>

FYI: You can find some example in QueryDSL's test code:

[scalikejdbc-interpolation/src/test/scala/scalikejdbc/QueryInterfaceSpec.scala](https://github.com/scalikejdbc/scalikejdbc/blob/1.7.x/scalikejdbc-interpolation/src/test/scala/scalikejdbc/QueryInterfaceSpec.scala)

`sqls` is alias for `SQLSyntax` object (enabled when you import `scalikejdbc.SQLInterpolation._`.). Methods that are defined on `object SQLSyntax` is available everywhere.

[scalikejdbc-interpolation-core/src/main/scala/scalikejdbc/interpolation/SQLSyntax.scala](https://github.com/scalikejdbc/scalikejdbc/blob/1.7.x/scalikejdbc-interpolation-core/src/main/scala/scalikejdbc/interpolation/SQLSyntax.scala)

<hr/>
#### And/Or conditions 
<hr/>

```scala
val o = Order.syntax("o")
val orders = withSQL {
  select
    .from(Order as o)
    .where
    .eq(o.productId, 123)
    .and
    .isNotNull(o.orderedAt)
  }.map(Order(o)).list.apply()

// select o.id as i_on_o, o.customer_id ci_on_o, o.product_id as pi_on_o, o.ordered_at as oa_on_o
// from orders o where o.product_id = ? and o.ordered_at is not null
```

```scala
val orders = withSQL {
  select(o.result.id).from(Order as o)
    .where
    .eq(o.productId, 123)
    .or
    .isNull(o.customerId)
  }.map(Order(o)).list.apply()

// select o.id as i_on_o from orders o where o.product_id = ? and o.customer_id is null
```

Adding round bracket is like this:

```scala
val ids = withSQL {
  select(o.result.id).from(Order as o)
    .where.isNotNull(o.accountId)
    .and.withRoundBracket { _.eq(o.productId, 1).or.eq(o.accountId, 2) }
  }.map(_.int(1)).list.apply()

// select o.id as i_on_o from orders o
// where o.account_id is not null 
// and (o.product_id = ? or o.account_id = ?)
```

or simply using `#append`:

```
select(o.result.id).from(Order as o).where.isNotNull(o.accountId)
  .and.append(sqls"(${o.productId} = ${pid} or ${o.accountId} = ${aid})")
```

<hr/>
#### Join queries
<hr/>

```scala
val orders: List[Order] = withSQL {
  select
    .from(Order as o)
    .innerJoin(Product as p).on(o.productId, p.id)
    .leftJoin(Account as a).on(o.accountId, a.id)
    .where.eq(o.productId, 123)
    .orderBy(o.id).desc
    .limit(4)
    .offset(0)
  }.map(Order(o, p, a)).list.apply()

// select o.*, p.*, a.* from orders o inner join products p on o.product_id = p.id
// left join accounts a on o.account_id = a.id
// where o.product_id = ? order by o.id desc limit ? offset ?
```

`.on(o.productId, p.id)` is simply converted to `sqls"${o.productId} = ${p.id}"`. If you need to write more complex condition to join tables, use `sqls` directly.

```scala
  .innerJoin(Product as p).on(sqls"${o.proudctId} = ${p.id} and ${o.deletedAt} is not null")

  // inner join products p on o.product_id = p.id and o.deleted_at is not null
```

<hr/>
#### Dynamic query building
<hr/>

```scala
def findOrder(id: Long, accountRequired: Boolean) = withSQL {
  select
    .from[Order](Order as o)
    .innerJoin(Product as p).on(o.productId, p.id)
    .map { sql =>
      if (accountRequired) sql.leftJoin(Account as a).on(o.accountId, a.id) else sql
    }.where.eq(o.id, 13)
  }.map { rs =>
    if (accountRequired) Order(o, p, a)(rs) else Order(o, p)(rs)
  }.single.apply()

// select o.*, p.*(, a.*) from orders o inner join products p on o.product_id = p.id
// (left join accounts a on o.account_id = a.id)
// where o.id = ?
```

If you just need to append optional conditions, `toAndConditionOpt`, and `toOrConditionOpt ` are useful.

```scala
val (productId, accountId) = (Some(1), None)
val ids = withSQL {
  select(o.result.id).from(Order as o)
    .where(sqls.toAndConditionOpt(
      productId.map(id => sqls.eq(o.productId, id)),
      accountId.map(id => sqls.eq(o.accountId, id))
    ))
    .orderBy(o.id)
}.map(_.int(1)).list.apply()

// select o.id as i_on_o from orders o
// where o.product_id = ? (and o.account_id = ?)
// order by o.id
```

<hr/>
#### in clause
<hr/>

```scala
val inClauseResults = withSQL {
  select.from(Order as o).where.in(o.id, Seq(1, 2, 3))
}.map(Order(o)).list.apply()

// select * from orders o where o.id in (?, ?, ?)
```

<hr/>
#### exists/notExists clause
<hr/>

```scala
withSQL {
  select(a.id).from(Account as a)
    .where.exists(select.from(Order as o).where.eq(o.accountId, a.id))
}.map(_.int(1)).list.apply()

// select a.id from accounts a
// where exists (select * from orders o where o.account_id = a.id)
```

It's also possible to pass `sqls` values.

```scala
withSQL {
  select(a.id).from(Account as a)
    .where.notExists(sqls"select ${o.id} from ${Order as o} where ${o.accountId} = ${a.id}")
}.map(_.int(1)).list.apply()

// select a.id from accounts a
// where not exists (select o.id from orders o where o.account_id = a.id)
```

<hr/>
#### between
<hr/>

```scala
withSQL {
  select(o.result.id).from(Order as o).where.between(o.id, 13, 22)
}.map(_.int(1)).list.apply()

// select o.id as i_on_o from orders o where o.id between ? and ?
```

<hr/>
#### distinct count
<hr/>

```scala
import sqls.{ distinct, count }
val productCount = withSQL {
  select(count(distinct(o.productId))).from(Order as o)
}.map(_.int(1)).single.apply().get

// select count(distinct o.product_id) from orders o
```

<hr/>
#### group by queries
<hr/>

```scala
import sqls.count
withSQL {
  select(o.accountId, count).from(Order as o)
    .where.isNotNull(o.accountId)
    .groupBy(o.accountId)
}.map(rs => (rs.int(1), rs.int(2))).list.apply()

// select o.account_id, count(1) from orders o
// where o.account_id is not null
// group by o.account_id
```

<hr/>
#### union, unionAll queries
<hr/>

```scala
withSQL {
  select(a.id).from(Account as a)
    .union(select(p.id).from(Product as p))
    //.unionAll(select(p.id).from(Product as p))
}.map(_.int(1)).list.apply()

// select a.id from accounts a
// union 
// select p.id from products p
```

<hr/>
#### Sub-queries
<hr/>

```scala
import SQLSyntax.{ sum, gt }
val x = SubQuery.syntax("x").include(o, p)
val preferredClients: List[(Int, Int)] = withSQL {
  select(sqls"${x(o).accountId} id", sqls"${sum(x(p).price)} as amount")
    .from { select.all(o, p).from(Order as o).innerJoin(Product as p).on(o.productId, p.id).as(x) }
    .groupBy(x(o).accountId)
    .having(gt(sum(x(p).price), 300))
    .orderBy(sqls"amount")
  }.map(rs => (rs.int("id"), rs.int("amount"))).list.apply()

// select x.account_id id, sum(x.price) as amount 
// from (select o.*, p.* from orders o inner join products p on o.product_id = p.id) x
// group by x.account_id
// having sum(x.price) > ?
// order by amount
```

<hr/>
#### Insert
<hr/>

```scala
withSQL {
  insert.into(Member).values(1, "Alice", DateTime.now)
}.update.apply()

// insert into members values (?, ?, ?)

withSQL {
  val m = Member.column
  insert.into(Member).namedValues(
    m.id -> 1, 
    m.name -> "Alice", 
    m.createdAt -> DateTime.now
  )
}.update.apply()

// insert into members (id, name, created_at) values (?, ?, ?)
```

Or `applyUpdate` is much simpler. But in some cases, applyUpdate causes compilation errors since Scala 2.10.1. This is not an issue of ScalikeJDBC. If you suffered it, use `withSQL { }.update.apply()` instead.

```scala
applyUpdate { insert.into(Member).values(2, "Bob", DateTime.now) }

// insert into members values (?, ?, ?)

val c = Member.column
applyUpdate {
  insert.into(Member).columns(c.id, c.name, c.createdAt).values(2, "Bob", DateTime.now)
}

// insert into members (id, name, created_at) values (?, ?, ?)
```

<hr/>
#### Insert select
<hr/>

```scala
case class Product(id: Int, name: Option[String], price: Int)
object Product extends SQLSyntaxSupport[Product]
case class LegacyProduct(id: Option[Int], name: Option[String], price: Int)
object LegacyProduct extends SQLSyntaxSupport[LegacyProduct]

val lp = LegacyProduct.syntax("lp")
withSQL {
  insert.into(Product).select(_.from(LegacyProduct as lp).where.isNotNull(lp.id))
}.update.apply()

// insert into products select lp.* from legacy_products lp where lp.id is not null
```

<hr/>
#### Delete
<hr/>

```scala
withSQL {
  delete.from(Member).where.eq(Member.column.id, 123)
}.update.apply()

// delete from members where id = ?
```

<hr/>
#### Update
<hr/>

```scala
withSQL {
  update(Member).set(
    Member.column.name -> "Chris",
    Member.column.updatedAt -> DateTime.now
  ).where.eq(Member.column.id, 2)
}.update.apply()

// update members set name = ?, updated_at = ? 
// where id = ?
```

<hr/>
#### Avoiding Method Name Conflict
<hr/>

For example, if your code already uses `select`, `insert` or `update` as method name, name confliction occurs.

```scala
def insert(e: Member)(implicit session: DBSession) {
  withSQL {
    insert // compilation error
      .into(Member).values(e.id, e.name)
  }.update.apply()
}
```

Use `QueryDSL` prefix or `insertInto`, `deleteFrom`.

```scala
def insert(e: Member)(implicit session: DBSession) {
  withSQL {
    QueryDSL.insert.into(Member).values(e.id, e.name)
  }.update.apply()
}

def insert(e: Member)(implicit session: DBSession) {
  withSQL {
    insertInto(Member).values(e.id, e.name)
  }.update.apply()
}

def delete(id: Long)(implicit session: DBSession) {
  withSQL {
    deleteFrom(Member).where.eq(Member.column.id, id)
  }.update.apply()
}
```



