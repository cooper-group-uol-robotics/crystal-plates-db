import requests
import json

url = "https://jfb.liverpool.ac.uk/performSearch"
cookies = {"SCIFORMATION": "36832ceedab974a8f4fa24b50d33"}
data = {
    "table": "CdbContainer",
    "format": "json",
    "query": "[0]",
    "crit0": "department",
    "op0": "OP_IN_NUM",
    "val0": "124",
}
response = requests.post(url, cookies=cookies, data=data)
print(response.status_code)

with open("output.json", "w") as f:
    json.dump(response.json(), f, indent=2)
