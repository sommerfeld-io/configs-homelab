title "Checks for devcontainer image"

include_controls 'linux-essentials' do
end

include_controls 'linux-baseline' do
  skip_control 'os-10'
  skip_control 'os-14'
  skip_control 'sysctl-01'
  skip_control 'sysctl-02'
  skip_control 'sysctl-05'
  skip_control 'sysctl-06'
  skip_control 'sysctl-07'
  skip_control 'sysctl-08'
  skip_control 'sysctl-09'
  skip_control 'sysctl-10'
  skip_control 'sysctl-12'
  skip_control 'sysctl-13'
  skip_control 'sysctl-14'
  skip_control 'sysctl-15'
  skip_control 'sysctl-16'
  skip_control 'sysctl-17'
  skip_control 'sysctl-20'
  skip_control 'sysctl-21'
  skip_control 'sysctl-22'
  skip_control 'sysctl-23'
  skip_control 'sysctl-24'
  skip_control 'sysctl-25'
  skip_control 'sysctl-26'
  skip_control 'sysctl-27'
  skip_control 'sysctl-28'
  skip_control 'sysctl-30'
end

control 'ansible-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed'

  describe file('/usr/bin/curl') do
    it { should exist }
    it { should be_executable }
  end
end
