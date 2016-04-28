require 'json'
require 'spec_helper'
require 'webmock/rspec'

describe 'SendGrid::Client' do
  it 'should accept a username and password' do
    expect(SendGrid::Client.new(api_user: 'test', api_key: 'test')).to be_an_instance_of(SendGrid::Client)
  end

  it 'should accept an api key' do
    expect(SendGrid::Client.new(api_key: 'sendgrid_123')).to be_an_instance_of(SendGrid::Client)
  end

  it 'should build the default url' do
    expect(SendGrid::Client.new.url).to eq('https://api.sendgrid.com')
  end

  it 'should build a custom url' do
    expect(SendGrid::Client.new(port: 3000, host: 'foo.sendgrid.com', protocol: 'tacos').url).to eq('tacos://foo.sendgrid.com:3000')
  end

  it 'should use the default endpoint' do
    expect(SendGrid::Client.new.endpoint).to eq('/api/mail.send.json')
  end

  it 'accepts a block' do
    expect { |b| SendGrid::Client.new(&b) }.to yield_control
  end

  describe ':send' do
    it 'should make a request to sendgrid' do
      stub_request(:any, 'https://api.sendgrid.com/api/mail.send.json')
        .to_return(body: {message: 'success'}.to_json, status: 200, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')
      mail = SendGrid::Mail.new
      res = client.send(mail)
      expect(res.code).to eq(200)
    end

    it 'should have an auth header when using an api key' do
      stub_request(:any, 'https://api.sendgrid.com/api/mail.send.json')
        .to_return(body: {message: 'success'}.to_json, status: 200, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')
      mail = SendGrid::Mail.new

      client.send(mail)

      expect(WebMock).to have_requested(:post, 'https://api.sendgrid.com/api/mail.send.json')
        .with(headers: {'Authorization' => 'Bearer abc123'})
    end

    it 'should have a username + password when using them' do
      stub_request(:any, 'https://api.sendgrid.com/api/mail.send.json')
        .to_return(body: {message: 'success'}.to_json, status: 200, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_user: 'foobar', api_key: 'abc123')
      mail = SendGrid::Mail.new

      res = client.send(mail)

      expect(WebMock).to have_requested(:post, 'https://api.sendgrid.com/api/mail.send.json')
        .with(body: 'api_key=abc123&api_user=foobar')
    end

    it 'should raise a SendGrid::Exception if status is not 200' do
      stub_request(:any, 'https://api.sendgrid.com/api/mail.send.json')
        .to_return(body: {message: 'error', errors: ['Bad username / password']}.to_json, status: 400, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_user: 'foobar', api_key: 'abc123')
      mail = SendGrid::Mail.new

      expect {client.send(mail)}.to raise_error(SendGrid::Exception)
    end

    it 'should not raise a SendGrid::Exception if raise_exceptions is disabled' do
      stub_request(:any, 'https://api.sendgrid.com/api/mail.send.json')
        .to_return(body: {message: 'error', errors: ['Bad username / password']}.to_json, status: 400, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_user: 'foobar', api_key: 'abc123', raise_exceptions: false)
      mail = SendGrid::Mail.new

      expect {client.send(mail)}.not_to raise_error
    end
  end

  describe ':bounces' do
    let :success_body do
      [
        {
          'created' => 1_443_651_125,
          'email' => 'testemail1@test.com',
          'reason' => '550 5.1.1 The email account that you tried to reach does not exist.',
          'status' => '5.1.1'
        }
      ]
    end

    let :headers do
      { 'Content-Type' => 'application/json', 'X-TEST' => 'yes' }
    end

    let(:api_user) { 'foobar' }
    let(:api_key) { 'abc123' }
    let(:endpoint) { 'https://api.sendgrid.com/v3/suppression/bounces' }

    it 'should make a request to sendgrid' do
      stub_request(:get, endpoint)
        .to_return(body: success_body.to_json, status: 200, headers: headers)

      client = SendGrid::Client.new(api_key: api_key)

      res = client.bounces
      expect(res.code).to eq(200)
      expect(res.body).to eq(success_body)
    end

    it 'should have a Bearer auth header when using an api key' do
      stub_request(:get, endpoint)
        .to_return(body: success_body.to_json, status: 200, headers: headers)

      client = SendGrid::Client.new(api_key: api_key)
      client.bounces

      expect(WebMock).to have_requested(:get, endpoint)
        .with(headers: { 'Authorization' => "Bearer #{api_key}" })
    end

    it 'should use basic auth when using a username + password' do
      stub_request(:get, "https://#{api_user}:#{api_key}@api.sendgrid.com/v3/suppression/bounces")
        .to_return(body: success_body.to_json, status: 200, headers: headers)

      client = SendGrid::Client.new(api_user: api_user, api_key: api_key)
      client.bounces
    end

    it 'should accept query params' do
      stub_request(:get, endpoint + '?start_time=1443651141&end_time=1443651154')
        .to_return(body: success_body.to_json, status: 200, headers: headers)

      client = SendGrid::Client.new(api_key: api_key)

      res = client.bounces(start_time: 1_443_651_141, end_time: 1_443_651_154)
      expect(res.code).to eq(200)
    end

    it 'should raise a SendGrid::Exception if status is not 200' do
      stub_request(:get, endpoint)
        .to_return(body: {message: 'error', errors: ['Bad username / password']}.to_json, status: 400, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: api_key)

      expect { client.bounces }.to raise_error(SendGrid::Exception)
    end
  end

  describe ':delete_bounce' do
    let :headers do
      { 'Content-Type' => 'application/json', 'X-TEST' => 'yes' }
    end

    let(:email) { 'test@testemail.com' }
    let(:api_user) { 'foobar' }
    let(:api_key) { 'abc123' }
    let(:endpoint) { "https://api.sendgrid.com/v3/suppression/bounces/#{email}" }

    it 'should make a request to sendgrid' do
      stub_request(:delete, endpoint)
        .to_return(status: 204, headers: headers)

      client = SendGrid::Client.new(api_key: api_key)

      res = client.delete_bounce(email)
      expect(res.code).to eq(204)
    end

    it 'should have a Bearer auth header when using an api key' do
      stub_request(:delete, endpoint)
        .to_return(status: 204, headers: headers)

      client = SendGrid::Client.new(api_key: api_key)
      client.delete_bounce(email)

      expect(WebMock).to have_requested(:delete, endpoint)
        .with(headers: { 'Authorization' => "Bearer #{api_key}" })
    end

    it 'should use basic auth when using a username + password' do
      stub_request(:delete, "https://#{api_user}:#{api_key}@api.sendgrid.com/v3/suppression/bounces/#{CGI.escape email}")
        .to_return(status: 204, headers: headers)

      client = SendGrid::Client.new(api_user: api_user, api_key: api_key)
      client.delete_bounce(email)
    end

    it 'should raise a SendGrid::Exception if status is not 204' do
      stub_request(:delete, endpoint)
        .to_return(body: {message: 'error', errors: ['Bad username / password']}.to_json, status: 400, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: api_key)

      expect { client.delete_bounce(email) }.to raise_error(SendGrid::Exception)
    end
  end

  describe ':create_whitelabel_domain' do
    let :success_body do
      <<-JSON
        {
          "id": 1,
          "domain": "example.com",
          "subdomain": "mail",
          "username": "john@example.com",
          "user_id": 7,
          "ips": [
            "192.168.1.1",
            "192.168.1.2"
          ],
          "custom_spf": true,
          "default": true,
          "legacy": false,
          "automatic_security": true,
          "valid": true,
          "dns": {
            "mail_cname": {
              "host": "mail.example.com",
              "type": "cname",
              "data": "u7.wl.sendgrid.net",
              "valid": true
            },
            "spf": {
              "host": "example.com",
              "type": "txt",
              "data": "v=spf1 include:u7.wl.sendgrid.net -all",
              "valid": true
            },
            "dkim1": {
              "host": "s1.<em>domainkey.example.com",
              "type": "cname",
              "data": "s1._domainkey.u7.wl.sendgrid.net",
              "valid": true
            },
            "dkim2": {
              "host": "s2.</em>domainkey.example.com",
              "type": "cname",
              "data": "s2._domainkey.u7.wl.sendgrid.net",
              "valid": true
            }
          }
        }
      JSON
    end

    it 'should make a request to sendgrid' do
      stub_request(:post, 'https://api.sendgrid.com/v3/whitelabel/domains')
        .to_return(body: success_body, status: 201, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')
      res = client.create_whitelabel_domain(domain: "example.com")
      expect(res.code).to eq(201)
    end
  end

  describe ':scopes' do
    let :success_body do
      <<-JSON
        "scopes": [
          "mail.send",
          "alerts.create",
          "alerts.read"
        ]
      JSON
    end

    it 'should make a request to sendgrid' do
      stub_request(:get, 'https://api.sendgrid.com/v3/scopes')
        .to_return(body: success_body, status: 200, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')

      res = client.scopes
      expect(res.code).to eq(200)
    end
  end

  describe ':api_keys' do
    let :success_body do
      <<-JSON
        "result": [
          {
            "api_key_id": "xxxxxxxx",
            "name": "My API Key"
          }
        ]
      JSON
    end

    it 'should make a request to sendgrid' do
      stub_request(:get, 'https://api.sendgrid.com/v3/api_keys')
        .to_return(body: success_body, status: 200, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')

      res = client.api_keys
      expect(res.code).to eq(200)
    end
  end

  describe ':create_api_key' do
    let :success_body do
      <<-JSON
        {
          "api_key": "SG.xxxxxxxx.yyyyyyyy",
          "api_key_id": "xxxxxxxx",
          "name": "My API Key",
          "scopes": [
            "mail.send",
            "alerts.create",
            "alerts.read"
          ]
        }
      JSON
    end

    it 'should make a request to sendgrid' do
      stub_request(:post, 'https://api.sendgrid.com/v3/api_keys')
        .to_return(body: success_body, status: 201, headers: {'X-TEST' => 'yes'})

      client = SendGrid::Client.new(api_key: 'abc123')

      res = client.create_api_key({
        name: "My API Key",
        scopes: [
          "mail.send",
          "alerts.create",
          "alerts.read"
        ]
      })

      expect(res.code).to eq(201)
    end

    describe ':create_subuser' do
      let :success_body do
        <<-JSON
          {
            "username": "John@example.com",
            "email": "John@example.com",
            "password": "johns_password",
            "ips": [
              "1.1.1.1",
              "2.2.2.2"
            ]
          }
        JSON
      end

      it 'should make a request to sendgrid' do
        stub_request(:post, 'https://api.sendgrid.com/v3/subusers')
          .to_return(body: success_body, status: 201, headers: {'X-TEST' => 'yes'})

        client = SendGrid::Client.new(api_key: 'abc123')

        res = client.create_subuser({
          username: "John@example.com",
          email: "John@example.com",
          password: "johns_password"
        })

        expect(res.code).to eq(201)
      end
    end

    describe ':update_filter_settings' do
      let :success_body do
        <<-JSON
          {
            "message": "success"
          }
        JSON
      end

      it 'should make a request to sendgrid' do
        stub_request(:post, 'https://api.sendgrid.com/api/filter.setup.json')
          .to_return(body: success_body, status: 200, headers: {'X-TEST' => 'yes'})

        client = SendGrid::Client.new(api_key: 'abc123')

        res = client.update_filter_settings({
          name: "eventnotify"
        })

        expect(res.code).to eq(200)
      end
    end
  end
end
