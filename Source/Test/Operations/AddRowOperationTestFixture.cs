﻿using System;
using NUnit.Framework;
using Rivet.Operations;
using System.Collections;

namespace Rivet.Test.Operations
{
	[TestFixture]
	public sealed class AddRowOperationTestFixture
	{
		private const string SchemaName = "schemaName";
		private const string TableName = "tableName";

		private static readonly Hashtable NewYork = new Hashtable
		{
			{"City", "New York"},
			{"State", "New York"},
			{"Population", 8336697}
		};

		private static readonly Hashtable LosAngeles = new Hashtable
		{
			{"City", "Los Angeles"},
			{"State", "California"},
			{"Population", 3857799}
		};

		public Hashtable[] ArrayofHashtables = {NewYork, LosAngeles};

		[SetUp]
		public void SetUp()
		{

		}

		[Test]
		public void ShouldSetPropertiesForAddRow()
		{
			var op = new AddRowOperation(SchemaName, TableName, ArrayofHashtables);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(TableName, op.TableName);
			Assert.AreEqual(2, op.Count());
			Assert.AreEqual(NewYork["City"], op.Column[0]["City"]);
			Assert.AreEqual(LosAngeles["City"], op.Column[1]["City"]);
			Assert.AreEqual(NewYork["State"], op.Column[0]["State"]);
			Assert.AreEqual(LosAngeles["State"], op.Column[1]["State"]);
			Assert.AreEqual(NewYork["Population"], op.Column[0]["Population"]);
			Assert.AreEqual(LosAngeles["Population"], op.Column[1]["Population"]);
		}

		[Test]
		public void ShouldWriteQueryForAddRow()
		{
			var op = new AddRowOperation(SchemaName, TableName, ArrayofHashtables);
			var expectedQuery = string.Format("insert into [schemaName].[tableName] (City, State, Population) values ('New York', 'New York', 8336697);{0}insert into [schemaName].[tableName] (City, State, Population) values ('Los Angeles', 'California', 3857799);{0}", Environment.NewLine);
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}
	}
}