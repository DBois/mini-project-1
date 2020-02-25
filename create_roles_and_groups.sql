-- If running the script for the 2nd time, uncomment the line below
--drop owned by unregistered, client, worker, admin_;
drop role if exists unregistered, client, worker, admin_;
drop user if exists unregistered_user, client_user, worker_user, admin_user;

create role unregistered;
create role client; 
create role worker;
create role admin_;

grant connect on database mp1_library to client, worker, admin_, unregistered;

grant select on table book_info, book to unregistered;

grant select on table book_info, book, client, client_book_transaction, "role" to client;
grant update on table client, client_book_transaction, book_info to client; 
grant insert on table client_book_transaction to client;
grant usage, select on sequence client_book_transaction_id_seq to client;

-- The role worker (libarian) can't loan a book - Since they have their own lib_card to login as a user.
grant execute on function loan_book to group client;

grant select on table "role", client, client_book_transaction, book, book_info, book_info_author, author to worker;
grant insert, delete, update  on table book, book_info to worker;
grant usage, select on sequence book_id_seq to worker;

grant select, insert, update, delete on all tables in schema public to admin_;
grant all privileges on all sequences in schema public to admin_;

create user unregistered_user with encrypted password '1234';
create user client_user with encrypted password 'Passw0rd';
create user worker_user with encrypted password 'Passw0rd';
create user admin_user with encrypted password 'Admin';

grant unregistered to unregistered_user;
grant client to client_user;
grant worker to worker_user; 
grant admin_ to admin_user;