title "Common checks for workstations, raspi nodes and container images"

control 'os-01' do
  impact 1.0
  title 'Verify OS properties'
  desc 'Ensure the machine image is running a valid OS'

  describe command('cat /etc/os-release') do
    its('stdout') { should match(/(Alpine|Ubuntu)/) }
  end

  describe package('bash') do
    it { should be_installed } if file('/etc/os-release').content.match?(/Ubuntu/)
  end

  describe package('ash') do
    it { should be_installed } if file('/etc/os-release').content.match?(/Alpine/)
  end
end
