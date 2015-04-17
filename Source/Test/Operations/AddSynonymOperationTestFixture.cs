﻿using NUnit.Framework;
using Rivet.Operations;

namespace Rivet.Test.Operations
{
	[TestFixture]
	public sealed class AddSynonymOperationTestFixture
	{
		private const string SchemaName = "schemaName";
		private const string Name = "name";
		private const string TargetSchemaName = "targetSchemaName";
		private const string TargetDatabaseName = "targetDataBaseName";
		private const string TargetObjectName = "targetObjectName";

		[Test]
		public void ShouldSetPropertiesForAddSynonym()
		{
			var op = new AddSynonymOperation(SchemaName, Name, TargetSchemaName, TargetDatabaseName, TargetObjectName);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(Name, op.Name);
			Assert.AreEqual(TargetSchemaName, op.TargetSchemaName);
			Assert.AreEqual(TargetDatabaseName, op.TargetDatabaseName);
			Assert.AreEqual(TargetObjectName, op.TargetObjectName);
			Assert.That(op.ObjectName, Is.EqualTo(string.Format("{0}.{1}", SchemaName, Name)));
		}

		[Test]
		public void ShouldSetPropertiesForRemoveSynonym()
		{
			var op = new RemoveSynonymOperation(SchemaName, Name);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(Name, op.Name);
		}

		[Test]
		public void ShouldWriteQueryForAddSynonym()
		{
			var op = new AddSynonymOperation(SchemaName, Name, TargetSchemaName, TargetDatabaseName, TargetObjectName);
			const string expectedQuery = "create synonym [schemaName].[name] for [targetDataBaseName].[targetSchemaName].[targetObjectName]";
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}

		[Test]
		public void ShouldWriteQueryForAddSynonymNoTargetDatabase()
		{
			var op = new AddSynonymOperation(SchemaName, Name, TargetSchemaName, "", TargetObjectName);
			const string expectedQuery = "create synonym [schemaName].[name] for [targetSchemaName].[targetObjectName]";
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}

	}
}