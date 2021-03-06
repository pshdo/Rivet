﻿using NUnit.Framework;
using Rivet.Operations;

namespace Rivet.Test.Operations
{
	[TestFixture]
	public sealed class UpdateTriggerOperationTestFixture
	{
		const string SchemaName = "schemaName";
		const string TriggerName = "triggerName";
		const string Definition = "as definition";

		[Test]
		public void ShouldSetPropertiesForUpdateTrigger()
		{
			var op = new UpdateTriggerOperation(SchemaName, TriggerName, Definition);
			Assert.AreEqual(SchemaName, op.SchemaName);
			Assert.AreEqual(TriggerName, op.Name);
			Assert.AreEqual(Definition, op.Definition);
			Assert.That(op.ObjectName, Is.EqualTo(string.Format("{0}.{1}", SchemaName, TriggerName)));
		}

		[Test]
		public void ShouldWriteQueryForAddTrigger()
		{
			var op = new UpdateTriggerOperation(SchemaName, TriggerName, Definition);
			const string expectedQuery = "alter trigger [schemaName].[triggerName] as definition";
			Assert.AreEqual(expectedQuery, op.ToQuery());
		}

	}
}