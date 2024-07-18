import os

print("All the env variables for the current build:")

for key, value in os.environ.items():
    print(f"{key}: {value}")
