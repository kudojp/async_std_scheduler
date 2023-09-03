# frozen_string_literal: true
require 'socket'
require 'resolv'

RSpec.describe AsyncScheduler do
  describe "DNS resolution" do
    def resolve_address_with_scheduler(hostname, port, family=nil, socket_type=nil)
      Thread.new do
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler scheduler
        ips = nil
        Fiber.schedule do
          ips = Socket.getaddrinfo(hostname, port, family=family, socket_type=socket_type)
        end
        scheduler.close
        ips
      end.value
    end

    it "resolves localhost successfully" do
      # NOTE:
      # Value of Socket::Constants::AF_INET6 seems to differ according to the OS.
      # - Linux: 10
      # - MacOS: 30
      # Thus, it is not hard-coded in tests below.
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 1, 6])
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 2, 17])
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 3, 0])
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 1, 6])
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 2, 17])
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 3, 0])
    end

    it "resolves google.com successfully" do
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)
      # NOTE: It does not check if this IP is really google.com.
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 1, 6])

      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 2, 17])

      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 3, 0])

      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)
      ipv6 = address_info[0][2]
      # NOTE: there could be multiple resolved IPv6 addresses.
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 1, 6])

      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)
      ipv6 = address_info[0][2]
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 2, 17])

      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)
      ipv6 = address_info[0][2]
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 3, 0])
    end
  end

  describe "DNS resolution performance" do
    def resolve_address_with_scheduler(hostname, port, num_times)
      Thread.new do
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler AsyncScheduler::Scheduler.new

        num_times.times do
          Fiber.schedule do
            Socket.getaddrinfo("www.google.com", 443)
          end
        end

        scheduler.close
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
      end.value
    end

    def resolve_address_with_multithreads(hostname, port, num_times)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      num_times.times do
        Thread.new do
          Socket.getaddrinfo("www.google.com", 443)
        end.join
      end
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    end

    it "resolves addresses in a Fiber.schedule block" do
      puts "👁  Confirm these things."
      puts "- Resolving with scheduler is faster than multithreading."
      puts "- Execution times of resolving scheduler do not improve in a liner manner."

      ["localhost", "google.com"].each do |hostname|
        puts "--------------------------"
        puts "|   Resolve #{hostname.ljust(10)}   |"
        puts "--------------------------"

        [1, 10, 100].each do |num_times|
          puts "## Resolving #{num_times} times:"
          puts "Resolve with scheduler:    #{resolve_address_with_scheduler(hostname, 443, num_times)}"
          puts "Resolve with multithreads: #{resolve_address_with_multithreads(hostname, 443, num_times)}"
          puts
        end
      end
    end
  end
end
