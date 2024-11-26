import pandas as pd

# Load the CSV file into a DataFrame
file_path = 'vms_uptime_info.csv' 
vm_data = pd.read_csv(file_path)

# Function to parse the uptime into days
def parse_uptime(uptime_str):
    try:
        days, hours, minutes = 0, 0, 0
        if "days" in uptime_str:
            parts = uptime_str.split(", ")
            days = int(parts[0].split()[0])
            hours = int(parts[1].split()[0]) if len(parts) > 1 else 0
            minutes = int(parts[2].split()[0]) if len(parts) > 2 else 0
        return days + (hours / 24) + (minutes / 1440)
    except:
        return 0  # If there's an issue parsing, return 0 days

# Apply the function to calculate the uptime in days
vm_data['UptimeDays'] = vm_data['Uptime'].apply(parse_uptime)

# Filter VMs that have been up for 7 or more days
vms_up_for_a_week = vm_data[vm_data['UptimeDays'] >= 7]

# Save the filtered VMs to a new CSV file
output_file = 'vms_up_for_a_week_or_more.csv'
vms_up_for_a_week.to_csv(output_file, index=False)

print(f"VMs up for a week or more have been saved to {output_file}")
