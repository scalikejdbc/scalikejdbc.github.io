---
title: One-to-X API - ScalikeJDBC
---

## One-to-X API

<hr/>
### Why One-to-x APIs are needed?
<hr/>

Users can write all the mapping operations by using `#map` or `#foldLeft`... with a lot of boilerplate code.

ScalikeJDBC provides you some useful APIs to map results to objects.

<div class="alert alert-warning">
Be aware that resolving multiple one-to-many relationships with a single join query may cause performance or data size problems when dealing with large number of rows.
</div>

<hr/>
### One-To-Many / One-To-Manies
<hr/>

Simple example:

```scala
case class Member(id: Long, name: String)
case class Group(id: Long, name: String, members: Seq[Member] = Nil)

object Group extends SQLSyntaxSupport[Group] {
  override val tableName = "groups"
  def apply(g: SyntaxProvider[Group])(rs: WrappedResultSet): Group = apply(g.resultName)(rs)
  def apply(g: ResultName[Group])(rs: WrappedResultSet): Group = new Group(rs.get(g.id), rs.get(g.name))
}

object Member extends SQLSyntaxSupport[Member] {
  override val tableName = "members"
  def apply(m: SyntaxProvider[Member])(rs: WrappedResultSet): Member = apply(m.resultName)(rs)
  def apply(m: ResultName[Member])(rs: WrappedResultSet): Member =
    new Member(rs.get(m.id), rs.get(m.name))

  def opt(m: SyntaxProvider[Member])(rs: WrappedResultSet): Option[Member] =
    rs.longOpt(m.resultName.id).map(_ => Member(m)(rs))
}

val (g, m) = (Group.syntax, Member.syntax)

val groups: Seq[Group] =
  withSQL { select.from(Group as g).leftJoin(Member as m).on(g.id, m.groupId) }
   .one(Group(g))
   .toMany(Member.opt(m))
   .map { (group, members) => group.copy(members = members) }
   .list
   .apply()
```

`one.toManies` supports 9 tables to join.

```scala
case class Member(id: Long, name: String)
case class Event(id: Long, name: String)
case class Group(id: Long, name: String,
  events: Seq[Event] = Nil, members: Seq[Member] = Nil)

// companion objects must be defined

val (g, m, e) = (Group.syntax, Member.syntax, Event.syntax)

val groups: Seq[Group] =
  withSQL {
    select
      .from(Group as g)
      .leftJoin(Member as m).on(g.id, m.groupId)
      .leftJoin(Event as e).on(g.id, e.groupId)
    }
    .one(Group(m))
    .toManies(
       rs => Member.opt(g)(rs),
       rs => Event.opt(e)(rs))
     .map { (group, members, events) => group.copy(members = members, events = events) }
     .list
     .apply()
```

<hr/>
### One-To-One
<hr/>

`one.toOne` for inner join queries.

```scala
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String,
  ownerId: Long, owner: Option[Owner] = None)

// companion objects must be defined

val (g, o) = (Group.syntax, Owner.syntax)

val groups: Seq[Group] =
  withSQL {
    select
      .from(Group as g)
      .innerJoin(Owner as o).on(g.ownerId, o.id)
  }
  .one(Group(g))
  .toOne(Owner(o))
  .map { (group, owner) => group.copy(owner = Some(owner)) }
  .list
  .apply()
```

If you don't want to define `owner` as an optional value, use `#map` instead.

```scala
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String, ownerId: Long, owner: Owner)

// companion objects must be defined

object Group extends SQLSyntaxSupport[Group] {
  def apply(g: SyntaxProvider[Group], o: SyntaxProvider[Owner])(rs: WrappedResultSet): Group =
    apply(g.resultName, o.resultName)(rs)
  def apply(g: ResultName[Group], o: ResultName[Owner])(rs: WrappedResultSet): Group =
    new Group(
      id = rs.long(g.id),
      name = rs.string(g.name),
      ownerId = rs.long(g.ownerId),
      group = Owner(id = rs.long(o.id)),
      name = rs.string(o.name))
}

val (g, o) = (Group.syntax, Owner.syntax)

val groups: Seq[Group] =
  withSQL {
    select.from(Group as g).innerJoin(Onwer as o).on(g.ownerId, o.id)
  }
  .map(Group(g, o))
  .list
  .apply()
```

`one.toOptionalOne` for outer join queries.

```scala
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String,
  ownerId: Option[Long] = None, owner: Option[Owner] = None)

// companion objects must be defined

val (g, o) = (Group.syntax, Owner.syntax)

val groups: Seq[Group] =
  withSQL {
    select.from(Group as g).leftJoin(Owner as o).on(g.ownerId, o.id)
  }
  .one(Group(g))
  .toOptionalOne(Owner.opt(o))
  .map { (group, owner) => group.copy(owner = Some(owner)) }
  .list
  .apply()
```

<hr/>
### About Entity Equality
<hr/>

In most cases, you will use case classes for entities. And basically it works fine. However, as you know, Scala (under 2.11) has 22 limitation and you cannot create a case class with more thatn 22 parameters. If your table has more than 22 columns, you need to create a normal class like this:

```scala
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)

object HugeTable extends SQLSyntaxSupport[HugeTable] {
  def apply(h: ResultName[HugeTable])(rs: WrappedResultSet) = new HugeTable(
    id = rs.long(h.id),
    c2 = rs.long(h.c2),
    ....
    c23 = rs.long(h.c23)
  )
}
```

The above code also works fine except for the use of one-to-x APIs. Case classes nicely overrides `#equals` method. But `HugeTable`'s `#equals` method won't work as you expect because it just predicates instance equality. So when you use normal classes and one-to-x APIs, you must override `#equals` method by yourself.

Since version 1.7.3, ScalikeJDBC provides `EntityEquality` trait like this:

```scala
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)
  extends EntityEquality {

  override val entityIdentity: Any = id
}
```

`#equals` method predicates equality with `entityIdentity` and the class is same. The above code use only `id` value for equality. If it isn't appropriate, define `entityIdentity` differently.

```scala
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)
  extends EntityEquality {

  override val entityIdentity: Any = s"$id, $c2, $c3, ... $23"
  override val entityIdentity: Any = (id, c2, c3)
}
```

If you're still using older version and you cannot upgrade version right now, see the `EntityEquality` implementation and do the same thing.

https://github.com/scalikejdbc/scalikejdbc/blob/master/scalikejdbc-core/src/main/scala/scalikejdbc/EntityEquality.scala

