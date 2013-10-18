﻿using System;
using NUnit.Framework;
using Rivet.Operations;

namespace Rivet.Test.Operations
{
	[TestFixture]
	public sealed class RemoveExtendedPropertyOperationTestFixture
	{
		private AddExtendedPropertyOperation _op;

		const string SchemaName = "schemaName";
		const string TableName = "tableName";
		const string ColumnName = "columnName";
		const string Name = "name";
		const string Value = "value";

		[SetUp]
		public void SetUp()
		{
		}

		[Test]
		public void ShouldSetPropertiesForRemoveExtendedProperty()
		{
			//For Schema
			var op = new RemoveExtendedPropertyOperation(SchemaName, Name);
			Assert.AreEqual(true, op.ForSchema);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(Name, op.Name);

			//For Table
			op = new RemoveExtendedPropertyOperation(SchemaName, TableName, Name);
			Assert.AreEqual(true, op.ForTable);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(TableName, op.TableName);
			Assert.AreEqual(Name, op.Name);

			//For Column
			op = new RemoveExtendedPropertyOperation(SchemaName, TableName, ColumnName, Name);
			Assert.AreEqual(true, op.ForColumn);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(TableName, op.TableName);
			Assert.AreEqual(ColumnName, op.ColumnName);
			Assert.AreEqual(Name, op.Name);
		}

		[Test]
		public void ShouldWriteQueryForRemoveExtendedPropertyForSchema()
		{
			var op = new RemoveExtendedPropertyOperation(SchemaName, Name);
			var expectedQuery = String.Format("EXEC sys.sp_dropextendedproperty{0}@name=N'name',{0}@level0type=N'SCHEMA', @level0name=N'schemaName'", Environment.NewLine);
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}

		[Test]
		public void ShouldWriteQueryForRemoveExtendedPropertyForTable()
		{
			var op = new RemoveExtendedPropertyOperation(SchemaName, TableName, Name);
			var expectedQuery = String.Format("EXEC sys.sp_dropextendedproperty{0}@name=N'name',{0}@level0type=N'SCHEMA', @level0name=N'schemaName',{0}@level1type=N'TABLE', @level1name='tableName'", Environment.NewLine);
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}

		[Test]
		public void ShouldWriteQueryForRemoveExtendedPropertyForColumn()
		{
			var op = new RemoveExtendedPropertyOperation(SchemaName, TableName, ColumnName, Name);
			var expectedQuery = String.Format("EXEC sys.sp_dropextendedproperty{0}@name=N'name',{0}@level0type=N'SCHEMA', @level0name=N'schemaName',{0}@level1type=N'TABLE', @level1name='tableName',{0}@level2type=N'COLUMN', @level2name='columnName'", Environment.NewLine);
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}
	}
}