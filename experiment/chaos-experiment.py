import boto3
import random

# Initialize boto3 clients for EC2 and Auto Scaling
ec2 = boto3.client('ec2', region_name='eu-north-1')
asg = boto3.client('autoscaling', region_name='eu-north-1')

def terminate_random_instance(auto_scaling_group_name):
    response = asg.describe_auto_scaling_groups(AutoScalingGroupNames=[auto_scaling_group_name])
    instances = response['AutoScalingGroups'][0]['Instances']
    if instances:
        instance_to_terminate = random.choice(instances)['InstanceId']
        ec2.terminate_instances(InstanceIds=[instance_to_terminate])
        print(f"Terminated instance: {instance_to_terminate}")

def toggle_security_group_rule(security_group_id, action, ip_protocol, from_port, to_port, cidr_ip):
    if action == 'add':
        ec2.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': ip_protocol,
                    'FromPort': from_port,
                    'ToPort': to_port,
                    'IpRanges': [{'CidrIp': cidr_ip}]
                }
            ]
        )
        print(f"Added rule to Security Group: {security_group_id}")
    elif action == 'remove':
        ec2.revoke_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': ip_protocol,
                    'FromPort': from_port,
                    'ToPort': to_port,
                    'IpRanges': [{'CidrIp': cidr_ip}]
                }
            ]
        )
        print(f"Removed rule from Security Group: {security_group_id}")
        

def read_terraform_output(file_path, output_key):
    try:
        with open(file_path, 'r') as file:
            for line in file:
                # Check if the line contains the output key
                if output_key in line:
                    # Extracting the value after the equals sign and stripping whitespace and quotes
                    value = line.split('=')[1].strip().strip('"')
                    return value
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
    return None
    

def main():
    terraform_output_file = 'output.txt'
    auto_scaling_group_name = read_terraform_output(terraform_output_file, "autoscaling_group_name")
    
    if auto_scaling_group_name is None:
        print("Auto Scaling Group name not found.")
        return

    security_group_id = 'sg-0645ed724e5d8bf00'
    random_action = random.choice(['terminate_instance', 'toggle_rule'])

    if random_action == 'terminate_instance':
        terminate_random_instance(auto_scaling_group_name)
    else:
        action = random.choice(['add', 'remove'])
        toggle_security_group_rule(security_group_id, action, 'tcp', 80, 80, '0.0.0.0/0')

if __name__ == "__main__":
    main()
