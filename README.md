# plscope-utils

## :warning: **Caution: rvo\-cs test build** :warning:

**_This branch, [`rvocs_test`](https://github.com/rvo-cs/plscope-utils/tree/rvocs_test), contains my own changes and fixes on top of the [`main`](https://github.com/rvo-cs/plscope-utils/tree/main) branch_**—that's what a fork is for after all.

**_Further, while the [`main`](https://github.com/rvo-cs/plscope-utils/tree/main) branch here was once synchronized with the [`upstream/main`](https://github.com/PhilippSalvisberg/plscope-utils) branch, there's no guarantee at all that this will continue in the future._**

If you're looking for the official **plscope-utils** project from Philipp Salvisberg, please see _[this link](https://github.com/PhilippSalvisberg/plscope-utils)_.

## Introduction
**plscope-utils** is a set of tools using PL/Scope [^1], intended to make it easier to use. It consists of the following 2 components:

- [Core Database Objects](/database/README.md)

	Provides relational views and PL/SQL packages to simplify common source code analysis tasks. Requires a server-side installation.

- [SQL Developer Extension: plscope-utils for SQL Developer](/sqldev/README.md)

   An extension for SQL Developer, providing "PL/Scope" nodes in the Connections tree, a context menu action, and viewers for tables, views, and PL/SQL nodes; plus some reports. Does not require any server-side installation.

[^1]: PL/Scope is a built-in PL/SQL static code analysis tool, which collects identifiers and their usage in PL/SQL source codes. PL/Scope has been available since the version 11.1 of the Oracle Database, and it has been significantly enhanced in version 12.2, with the addition of the collection of SQL identifiers, and SQL statements, in PL/SQL source codes. 

## Releases

Binary releases are provided for the SQL Developer extension only.

**_Rvo-cs test builds may be available in the [Releases](https://github.com/rvo-cs/plscope-utils/releases) section._**

Official releases of the **plscope-utils** project are available _[here](https://github.com/PhilippSalvisberg/plscope-utils/releases)_.

## License

plscope-utils is licensed under the Apache License, Version 2.0.

You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
