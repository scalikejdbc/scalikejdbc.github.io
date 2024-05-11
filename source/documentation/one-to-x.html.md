---
title: One-to-X API - ScalikeJDBC
---

## One-to-X API

<hr/>
### Why One-to-x APIs are needed?
<hr/>

While users can perform mapping operations using methods like `#map` or `#foldLeft`, these often require extensive boilerplate code. ScalikeJDBC offers specialized APIs that simplify the mapping of results to objects.

<div class="alert alert-warning">
Be aware that resolving multiple one-to-many relationships with a single join query may lead to performance or data size issues when handling a large number of rows.
</div>

<hr/>
### One-To-Many / One-To-Manies
<hr/>

Here is a simple example:
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
   .list()
   .apply()
```

`one.toManies` supports up to 9 tables for joining.

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
    .one(Group(g))
    .toManies(
       rs => Member.opt(g)(rs),
       rs => Event.opt(e)(rs))
     .map { (group, members, events) => group.copy(members = members, events = events) }
     .list()
     .apply()
```

<hr/>
### One-To-One
<hr/>

`one.toOne` for inner join queries:

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

For optional relationships, use `#map`:

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

or `one.toOptionalOne` for outer join queries:

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

Typically, entities are represented using case classes. However, Scala versions below 2.11 limit case classes to 22 parameters. If your table has more than 22 columns, you'll need to use a normal class:


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

The code works correctly except when using one-to-x APIs. Case classes automatically override the `#equals` method, facilitating proper equality checks. However, the `#equals` method in a regular class like `HugeTable` only assesses instance equality, which may not yield the expected behavior. Therefore, when using non-case classes with one-to-x APIs, it's crucial to manually override the `#equals` method.

Starting from version 1.7.3, ScalikeJDBC includes the `EntityEquality` trait to simplify this process:

```scala
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)
  extends EntityEquality {

  override val entityIdentity: Any = id
}
```

The `#equals` method determines equality based on `entityIdentity` and whether the objects belong to the same class. In the provided code, equality is solely based on the id value. If this approach doesn't suit your needs, you can redefine `entityIdentity` to incorporate additional or different attributes to better reflect your equality criteria.

```scala
class HugeTable(
  val id: Long, val c2: String, val c3: String .... val c23: String)
  extends EntityEquality {

  override val entityIdentity: Any = s"$id, $c2, $c3, ... $23"
  override val entityIdentity: Any = (id, c2, c3)
}
```

If you are using an older version and cannot upgrade at this time, you can refer to the `EntityEquality` implementation and replicate its functionality in your environment.

https://github.com/scalikejdbc/scalikejdbc/blob/master/scalikejdbc-core/src/main/scala/scalikejdbc/EntityEquality.scala

