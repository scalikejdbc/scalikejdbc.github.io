---
title: One-to-X API - ScalikeJDBC
---

## One-to-X API

<hr/>
### Why One-to-x APIs are needed?
<hr/>

Users can write all the mapping operations by using `#map` or `#foldLeft`... with a lot of boilerplate code.

ScalikeJDBC provides you some useful APIs to map results to objects.

<hr/>
### One-To-Many / One-To-Manies
<hr/>

Simple example:

```java
case class Member(id: Long, name: String)
case class Group(id: Long, name: String,
  members: Seq[Member] = Nil)

object Group extends SQLSyntaxSupport[Group] { /* ... */ }
object Member extends SQLSyntaxSupport[Member] {
  override val tableName = "members"
  def opt(m: ResultName[Member])(rs: WrappedResultSet) = rs.longOpt(m.id).map(_ => Member(m)(rs))
}

val (g, m) = (Group.syntax, Member.syntax)
val groups: List[Group] = withSQL {
    select.from(Group as g).leftJoin(Member as m).on(g.id, m.groupId)
  }.one(Group(g))
   .toMany(Member.opt(m))
   .map { (group, members) => group.copy(members = members) }
   .list.apply()
```

`one.toManies` supports 5 tables to join.

```java
case class Member(id: Long, name: String)
case class Event(id: Long, name: String) { /* ... */ }
case class Group(id: Long, name: String,
  events: Seq[Event] = Nil,
  members: Seq[Member] = Nil)

val (g, m, e) = (Group.syntax, Member.syntax, Event.syntax)
val groups: List[Group] = withSQL {
  select
    .from(Group as g)
    .leftJoin(Member as m).on(g.id, m.groupId)
    .leftJoin(Event as e).on(g.id, e.groupId)
  }.one(Group(m))
   .toManies(
     rs => Member.opt(g)(rs),
     rs => Event(e)(rs))
   .map { (group, members, events) => group.copy(members = members, events = events) }
   .list.apply()
```

<hr/>
### One-To-One
<hr/>

`one.toOne` for inner join queries.

```java
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String,
  ownerId: Long,
  owner: Option[Owner] = None) { /* ... */ }

val (g, o) = (Group.syntax, Owner.syntax)
val groups: List[Group] = withSQL {
  select
    .from(Group as g)
    .innerJoin(Owner as o).on(g.ownerId, o.id)
  }.one(Group(g))
   .toOne(Owner(o))
   .map { (group, owner) => group.copy(owner = Some(owner)) }
   .list.apply()
```

If you don't want to define `owner` as an optional value, use `#map` instead.

```java
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String,
  ownerId: Long,
  owner: Owner)

object Group extends SQLSyntaxSupport[Group] {
  def apply(g: ResultName[Group], o: ResultName[Owner])(rs: WrappedResultSet) = new Group(
    id = rs.long(g.id),
    name = rs.string(g.name),
    ownerId = rs.long(g.ownerId),
    group = Owner(id = rs.long(o.id),
    name = rs.string(o.name))
  )
}

val (g, o) = (Group.syntax, Owner.syntax)
val groups: List[Group] = withSQL {
    select.from(Group as g).innerJoin(Onwer as o).on(g.ownerId, o.id)
  }.map(Group(g, o)).list.apply()
```

`one.toOptionalOne` for outer join queries.

```java
case class Owner(id: Long, name: String)
case class Group(id: Long, name: String,
  ownerId: Option[Long] = None,
  owner: Option[Owner] = None) { /* ... */ }

val (g, o) = (Group.syntax, Owner.syntax)
val groups: List[Group] = withSQL {
    select.from(Group as g).leftJoin(Owner as o).on(g.ownerId, o.id)
  }.one(Group(g))
   .toOptionalOne(Owner.opt(o))
   .map { (group, owner) => group.copy(owner = owner) }
   .list.apply()
```

<hr/>
### About Entity Equality
<hr/>

In most cases, you will use case classes for entities. And basically it works fine. However, as you know, Scala (under 2.11) has 22 limitation and you cannot create a case class with more thatn 22 parameters. If your table has more than 22 columns, you need to create a normal class like this:

```java
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

```java
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String) 
  extends EntityEquality {

  override val entityIdentity: Any = id
}
```

`#equals` method predicates equality with `entityIdentity` and the class is same. The above code use only `id` value for equality. If it isn't appropriate, define `entityIdentity` differently.

```java
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)
  extends EntityEquality {

  override val entityIdentity: Any = s"$id, $c2, $c3, ... $23"
  override val entityIdentity: Any = (id, c2, c3)
}
```

If you're still using older version and you cannot upgrade version right now, see the `EntityEquality` implementation and do the same thing.

https://github.com/scalikejdbc/scalikejdbc/blob/develop/scalikejdbc-library/src/main/scala/scalikejdbc/EntityEquality.scala

