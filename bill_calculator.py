# Simple Bill Calculator

price_input = input("Enter the price of one item: ")
quantity_input = input("Enter the quantity: ")

price = float(price_input)
quantity = int(quantity_input)

total = price * quantity

print(f"{quantity} items at {price:.2f} each = {total:.2f}")
