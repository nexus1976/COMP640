# COMP640 Group Project - Group 6

### Members and Responsibilities
- Yashin Rodriguez - Python Queries
- Tim Walewangko - ER Diagram
- Daniel Graham - Database implementation

All 3 of us equally participated in the overall design and coalescing of Python queries into an executable format.

## Running
To run this project, you must have Docker and Docker Compose installed and available (most easily via installing Docker Desktop).
From a terminal, at the root of this project, you can run the following command in order to get the Postgrest database with its structure and data:
   `docker compose up -d`

Now that you have a local Postgres server with our group project database `comp640DB` running, you can use a client tools like pgAdmin or DBeaver to connect using the following connection properties (these details are also located in the file `docker-compose.yml`):
```
Server = localhost (this might also need to be host.docker.internal depending on how you choose to run your client tooling)
Port = 5432
Database = comp640DB
User = postgres
Password = password
```

You will also need a working Python 3.13+ environment with the following pip packages installed in order to run the executable Python script `main.py` which demonstrates the queries.
#### pip packages
- `sqlalchemy`
- `psycopg2-binary`
- `pandas`

## Deliverables
1. The ER diagram (with keys, constraints, and cardinalities) is located at the root of this project in the file `ER-Diagram.pdf`.
2. You can look at the file `init.sql` to see the database structure implementation, the 3 business rules enforcement, and how we seeded the database with data. There are liberal comments in here documenting the business rules as well as commented out SQL tests to demonstrate said rules.
3. We developed the Python queries leveraging a Jupyter notebook (this is the file `canonicalqueries.ipynb`). If you want to utilize this notebook, it is suggested to have a working local installation of Anaconda along with Visual Studio Code with all of the Python and Jupyter extenstions by Microsoft installed. However, if you simply want to demonstrate the queries via their parameterized execution, simply run the Python script `main.py` in a terminal by issuing the command `python main.py` and follow the prompts.