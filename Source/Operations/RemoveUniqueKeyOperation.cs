﻿using System;

namespace Rivet.Operations
{
	public sealed class RemoveUniqueKeyOperation : TableObjectOperation
	{
		public RemoveUniqueKeyOperation(string schemaName, string tableName, string[] columnName)
			: base(schemaName, tableName, new ConstraintName(schemaName, tableName, columnName, ConstraintType.UniqueKey).ToString())
		{
			ColumnName = (string[])columnName.Clone();
		}

		public RemoveUniqueKeyOperation(string schemaName, string tableName, string name)
			: base(schemaName, tableName, name)
		{
		}

		public string[] ColumnName { get; private set; }

		public override string ToIdempotentQuery()
		{
			return string.Format("if object_id('{0}.{1}', 'UQ') is not null{2}\t{3}", SchemaName, Name, Environment.NewLine, ToQuery());
		}

		public override string ToQuery()
		{
			return string.Format("alter table [{0}].[{1}] drop constraint [{2}]", SchemaName, TableName, Name);
		}
	}
}
