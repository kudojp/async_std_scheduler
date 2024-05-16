# frozen_string_literal: true

RSpec.describe AsyncScheduler do
  before do
    File.open("./log1.txt", "w"){|f| f.write("log1") }
    File.open("./log2.txt", "w"){|f| f.write("log2") }
    File.open("./log3.txt", "w"){|f| f.write("log3") }
  end

  it "reads in fibers with AsyncScheduler::Scheduler" do
    t = Time.now
    thread = Thread.new do
      t = Time.now
      Fiber.set_scheduler AsyncScheduler::Scheduler.new

      Fiber.schedule do
        f1 = File.open("./log1.txt", "r"){|f| f.read() }
        puts '## finished reading in the first fiber: '
        puts f1
      end
      Fiber.schedule do
        f2 = File.open("./log2.txt", "r"){|f| f.read() }
        puts '## finished reading in the second fiber'
        puts f2
      end
      Fiber.schedule do
        f3 = File.open("./log3.txt", "r"){|f| f.read() }
        puts '## finished reading in the third fiber'
        puts f3
      end
    end
    thread.join
    puts "It took #{Time.now - t} seconds to run three fibers concurrently."
  end
end
