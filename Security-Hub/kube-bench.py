import boto3
import datetime
import uuid

# >>> CHANGE THESE <<<
ACCOUNT_ID = "165220828225"      # your AWS account ID
REGION = "us-east-1"             # region where Security Hub + Lambda are

securityhub = boto3.client("securityhub", region_name=REGION)

# Use timezone-aware UTC datetime (no deprecation warning)
now = datetime.datetime.now(datetime.timezone.utc).isoformat()

finding_uuid = str(uuid.uuid4())

response = securityhub.batch_import_findings(
    Findings=[
        {
            "SchemaVersion": "2018-10-08",
            "Id": f"test-kube-bench-finding-{finding_uuid}",
            # ProductArn MUST be a valid product; for test we use Security Hub "default" product
            "ProductArn": f"arn:aws:securityhub:{REGION}:{ACCOUNT_ID}:product/{ACCOUNT_ID}/default",

            # IMPORTANT: set ProductName so Filters.ProductName = "kube-bench" works
            "ProductName": "kube-bench",

            "GeneratorId": "kube-bench-manual-test",
            "AwsAccountId": ACCOUNT_ID,
            "Types": [
                "Software and Configuration Checks/Industry and Regulatory Standards/CIS Benchmarks"
            ],
            "CreatedAt": now,
            "UpdatedAt": now,
            "Severity": {
                "Label": "HIGH"
            },
            "Title": "kube-bench CIS control failed (manual test)",
            "Description": "Manually created kube-bench-style finding for testing CSV export.",
            "Resources": [
                {
                    "Type": "AwsEksCluster",
                    "Id": f"arn:aws:eks:{REGION}:{ACCOUNT_ID}:cluster/test-eks-cluster",
                    "Region": REGION,
                }
            ],
            "RecordState": "ACTIVE",
            "Workflow": {
                "Status": "NEW"
            },
        }
    ]
)

print("Batch import response:", response)
