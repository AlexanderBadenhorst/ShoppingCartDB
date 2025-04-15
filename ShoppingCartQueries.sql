-------------TABLES--------------
-- 1. Products Table (Menu)
CREATE TABLE Products (
    Id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- 2. Cart Table (to store items added by users)
CREATE TABLE Cart (
    ProductId INT PRIMARY KEY,
    Qty INT NOT NULL,
    FOREIGN KEY (ProductId) REFERENCES Products(Id)
);

-- 3. Users Table (customer information)
CREATE TABLE Users (
    User_ID INT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL
);

-- 4. OrderHeader Table (order summary)
CREATE TABLE OrderHeader (
    OrderID SERIAL PRIMARY KEY,
    User_ID INT NOT NULL,
    OrderDate TIMESTAMP NOT NULL,
    FOREIGN KEY (User_ID) REFERENCES Users(User_ID)
);


-- 5. OrderDetails Table (order details)
CREATE TABLE OrderDetails (
    OrderID INT,
    ProdID INT,
    Qty INT NOT NULL,
    PRIMARY KEY (OrderID, ProdID),
    FOREIGN KEY (OrderID) REFERENCES OrderHeader(OrderID),
    FOREIGN KEY (ProdID) REFERENCES Products(Id)
);


-------------BASIC INSERTS------------
-- Insert products into the Products table
INSERT INTO Products (Id, name, price) VALUES
(1, 'Coke', 10.00),
(2, 'Chips', 5.00);

-- Insert users into the Users table
INSERT INTO Users (User_ID, Username) VALUES
(1, 'Arnold'),
(2, 'Sheryl');


-------------FUNCTIONALITY LOGIC-------------
--ADDING ITEMS TO CART
-- Add Coke (ProductId = 1) to the Cart
INSERT INTO Cart (ProductId, Qty)
VALUES (1, 1)
ON CONFLICT (ProductId)
DO UPDATE SET Qty = Cart.Qty + 1;

-- Add Chips (ProductId = 2) to the Cart
INSERT INTO Cart (ProductId, Qty)
VALUES (2, 1)
ON CONFLICT (ProductId)
DO UPDATE SET Qty = Cart.Qty + 1;

-- Check the Cart contents
SELECT * FROM Cart;

--REMOVING ITEMS FROM CART
-- If the quantity is more than 1, subtract 1 from it.
-- If the quantity is 1, delete the item from the cart.
-- Remove a Coke (ProductId = 1) from the cart
DO $$
BEGIN
    IF (SELECT Qty FROM Cart WHERE ProductId = 1) > 1 THEN
        UPDATE Cart
        SET Qty = Qty - 1
        WHERE ProductId = 1;
    ELSE
        DELETE FROM Cart WHERE ProductId = 1;
    END IF;
END $$;

-- Remove Chips (ProductId = 2) from the cart (use same logic)
DO $$
BEGIN
    IF (SELECT Qty FROM Cart WHERE ProductId = 2) > 1 THEN
        UPDATE Cart
        SET Qty = Qty - 1
        WHERE ProductId = 2;
    ELSE
        DELETE FROM Cart WHERE ProductId = 2;
    END IF;
END $$;

-- Check the cart contents after removing items
SELECT * FROM Cart;


----------------CHECKOUT LOGIC---------------
-- Insert the user’s order into the OrderHeader table, along with the current date and time.
-- Insert the cart contents into the OrderDetails table, linking each item to the new OrderID.
-- Clear the cart after checkout.

-- Step 5A: Insert into OrderHeader
INSERT INTO OrderHeader (User_ID, OrderDate)
VALUES (1, NOW())  -- Assume user with User_ID = 1 is checking out

-- Step 5B: Insert into OrderDetails using the latest OrderID
INSERT INTO OrderDetails (OrderID, ProdID, Qty)
SELECT (SELECT MAX(OrderID) FROM OrderHeader), ProductId, Qty
FROM Cart;

-- Step 5C: Clear the cart after checkout
DELETE FROM Cart;

-- View the contents of OrderHeader
SELECT * FROM OrderHeader;

-- View the contents of OrderDetails
SELECT * FROM OrderDetails;

--QUERYING ORDER DATA
-- Printing a Single Order:
-- Use SELECT with INNER JOIN to show details of a specific order.

-- Printing All Orders for a Day’s Shopping:
-- Filter orders by date.

-- Query 1: Print a single order (e.g., OrderID = 1)
SELECT oh.OrderID, u.Username, oh.OrderDate, p.name AS ProductName, od.Qty, p.price, (p.price * od.Qty) AS TotalPrice
FROM OrderHeader oh
INNER JOIN Users u ON oh.User_ID = u.User_ID
INNER JOIN OrderDetails od ON oh.OrderID = od.OrderID
INNER JOIN Products p ON od.ProdID = p.Id
WHERE oh.OrderID = 1;

-- Query 2: Print all orders for a specific day (e.g., all orders on 2025-03-24)
SELECT oh.OrderID, u.Username, oh.OrderDate, p.name AS ProductName, od.Qty, p.price, (p.price * od.Qty) AS TotalPrice
FROM OrderHeader oh
INNER JOIN Users u ON oh.User_ID = u.User_ID
INNER JOIN OrderDetails od ON oh.OrderID = od.OrderID
INNER JOIN Products p ON od.ProdID = p.Id
WHERE DATE(oh.OrderDate) = '2025-03-24';

--------BONUS--------
-- Function 1: add_to_cart
-- This function will:
-- Take ProductId as input.
-- If the product exists in the cart, it updates the quantity by 1.
-- If the product doesn’t exist, it inserts the product with Qty = 1.

CREATE OR REPLACE FUNCTION add_to_cart(p_ProductId INT)
RETURNS VOID AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Cart c WHERE c.ProductId = p_ProductId) THEN
        UPDATE Cart
        SET Qty = Qty + 1
        WHERE Cart.ProductId = p_ProductId;  -- Updated reference
    ELSE
        INSERT INTO Cart (ProductId, Qty)
        VALUES (p_ProductId, 1);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function 2: remove_from_cart
-- This function will:
-- Take ProductId as input.
-- If the quantity is greater than 1, it subtracts 1.
-- If the quantity is 1, it deletes the product from the cart.

CREATE OR REPLACE FUNCTION remove_from_cart(p_ProductId INT)
RETURNS VOID AS $$
BEGIN
    IF (SELECT c.Qty FROM Cart c WHERE c.ProductId = p_ProductId) > 1 THEN
        UPDATE Cart
        SET Qty = Qty - 1
        WHERE Cart.ProductId = p_ProductId;  -- Updated reference
    ELSE
        DELETE FROM Cart WHERE Cart.ProductId = p_ProductId;
    END IF;
END;
$$ LANGUAGE plpgsql;

--USING FUNCTIONS
-- Add a Coke (ProductId = 1) to the cart
SELECT add_to_cart(1);

-- Remove a Coke (ProductId = 1) from the cart
SELECT remove_from_cart(1);


-------------BASIC TEST PLAN----------------
--Step 1: Check if the cart is empty (start with a clean state)
SELECT * FROM Cart;

--Step 2: Add a product to the cart using add_to_cart
-- Add a Coke (ProductId = 1) to the cart
SELECT add_to_cart(1);
--Then, check the cart again:
SELECT * FROM Cart;
--The cart should now have 1 Coke:

-- Step 3: Add the same product again to increase its quantity
SELECT add_to_cart(1);  -- Add another Coke
-- Check the cart contents
SELECT * FROM Cart;
-- The cart should now have 2 Cokes

-- Step 4: Add a different product (e.g., Chips)
SELECT add_to_cart(2);  -- Add Chips (ProductId = 2)
-- Check the cart contents
SELECT * FROM Cart;
-- The cart should now have 2 Cokes and 1 Chips

--Step 5: Remove 1 Coke using remove_from_cart
SELECT remove_from_cart(1);  -- Remove 1 Coke
-- Check the cart contents
SELECT * FROM Cart;
-- The cart should now have 1 Coke and 1 Chips

--Step 6: Remove 1 more Coke (this should remove it entirely)
SELECT remove_from_cart(1);  -- Remove the last Coke
-- Check the cart contents
SELECT * FROM Cart;
-- The cart should now have only 1 Chips

--Step 7: Checkout Process
-- simulate the user checking out by placing an order:
--1: Insert into OrderHeader (with current timestamp):
INSERT INTO OrderHeader (User_ID, OrderDate) 
VALUES (1, NOW());  -- Assume User 1 is checking out
--2: Get the OrderID that was just generated:
SELECT MAX(OrderID) AS LastOrderID FROM OrderHeader;
--Let’s say the result is OrderID = 1.
--3: Insert cart contents into OrderDetails:
INSERT INTO OrderDetails (OrderID, ProdID, Qty)
SELECT (SELECT MAX(OrderID) FROM OrderHeader), ProductId, Qty
FROM Cart;
--4: Clear the cart after checkout:
DELETE FROM Cart;
--5: Verify that the cart is now empty:
SELECT * FROM Cart;

-- Step 8: Check Orders
-- check order details
--1: View the contents of the OrderHeader table:
SELECT * FROM OrderHeader;
--2: View the details of all orders (with product info):
SELECT oh.OrderID, oh.OrderDate, p.Name AS Product, od.Qty
FROM OrderHeader oh
JOIN OrderDetails od ON oh.OrderID = od.OrderID  -- correct column
JOIN Products p ON od.ProdID = p.Id
ORDER BY oh.OrderID;
--3: Print a single order (for example, OrderID = 1):
SELECT oh.OrderID, oh.OrderDate, p.Name AS Product, od.Qty
FROM OrderHeader oh
JOIN OrderDetails od ON oh.OrderID = od.OrderID  -- correct column
JOIN Products p ON od.ProdID = p.Id
WHERE oh.OrderID = 1; --change orderID as needed


-- Step 9: Constraint Testing Inserts

-- INVALID INSERT: Duplicate ProductId in Products (violates PRIMARY KEY)
-- Expected: FAIL - Product ID 1 already exists
INSERT INTO Products (Id, name, price)
VALUES (1, 'Duplicate Coke', 12.00);

-- INVALID INSERT: NULL product name (violates NOT NULL constraint)
-- Expected: FAIL - 'name' cannot be NULL
INSERT INTO Products (Id, name, price)
VALUES (3, NULL, 15.00);

-- INVALID INSERT: Invalid foreign key in Cart (ProductId does not exist in Products)
-- Expected: FAIL - no product with ID = 99
INSERT INTO Cart (ProductId, Qty)
VALUES (99, 1);

-- INVALID INSERT: Duplicate ProductId in Cart (violates PRIMARY KEY)
-- Expected: FAIL if ProductId = 2 already exists in cart
INSERT INTO Cart (ProductId, Qty)
VALUES (2, 1);

-- INVALID INSERT: Invalid User_ID in OrderHeader (foreign key violation)
-- Expected: FAIL - User_ID 99 does not exist
INSERT INTO OrderHeader (User_ID, OrderDate)
VALUES (99, NOW());

-- INVALID INSERT: Invalid ProdID in OrderDetails (foreign key violation)
-- Expected: FAIL - Product with ID 99 does not exist
INSERT INTO OrderDetails (OrderID, ProdID, Qty)
VALUES ((SELECT MAX(OrderID) FROM OrderHeader), 99, 2);

-- INVALID INSERT: Invalid OrderID in OrderDetails (foreign key violation)
-- Expected: FAIL - No order with ID 999
INSERT INTO OrderDetails (OrderID, ProdID, Qty)
VALUES (999, 1, 1);

-- VALID INSERT: New product with valid data
INSERT INTO Products (Id, name, price)
VALUES (3, 'Chocolate', 8.50);

-- VALID INSERT: Add new user
INSERT INTO Users (User_ID, Username)
VALUES (3, 'PeterP');
