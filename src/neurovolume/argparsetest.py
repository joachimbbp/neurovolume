import argparse

parser = argparse.ArgumentParser(description="legit just a test")

#-- makes it optional 

parser = argparse.ArgumentParser(description="this tests some argument parser stuff")
parser.add_argument("scan", metavar="scan", type=str, help="just write a string, this is a test")
parser.add_argument("-n", "--numbers", type=int, nargs='*')

args = parser.parse_args()
scan = args.scan
numbers = args.numbers
print(f"scan is {scan}")
print(f"numbers are{numbers}")
#metavar is how it is displayed, feels a bit bloat-y to me ngl