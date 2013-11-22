﻿using System;

namespace Rivet.Operations
{
	public sealed class AddCheckConstraintOperation : Operation
	{
		public AddCheckConstraintOperation(string schemaName, string tableName, string name, string expression, bool notForReplication)
		{
			Name = name;
			SchemaName = schemaName;
			TableName = tableName;
			Expression = expression;
			NotForReplication = notForReplication;
		}

		public string Name { get; private set; }
		public string SchemaName { get; private set; }
		public string TableName { get; private set; }
		public string Expression { get; private set; }
		public bool NotForReplication { get; private set; }

		public override string ToIdempotentQuery()
		{
			return String.Format("if object_id('{0}', 'C') is null{1}\t{2}", Name, Environment.NewLine, ToQuery());
		}

		public override string ToQuery()
		{
			var notForReplicationclause = "";
			if (NotForReplication)
			{
				notForReplicationclause = " not for replication";
			}

			return string.Format("alter table [{0}].[{1}] add constraint [{2}] check{4} ({3}) ",
				SchemaName, TableName, Name, Expression, notForReplicationclause);
		}
	}
}
