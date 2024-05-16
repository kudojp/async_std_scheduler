# frozen_string_literal: true

RSpec.describe AsyncScheduler do
  before do
    File.delete("./log1.txt")
    File.delete("./log2.txt")
    File.delete("./log3.txt")
  end

  it "writes in fibers with AsyncScheduler::Scheduler" do
    t = Time.now
    thread = Thread.new do
      t = Time.now
      Fiber.set_scheduler AsyncScheduler::Scheduler.new

      Fiber.schedule do
        File.open("./log1.txt", "w"){|f| f.write("aaa") }
        puts '## finished writing in the first fiber'
      end
      Fiber.schedule do
        File.open("./log2.txt", "w"){|f| f.write("bbb") }
        puts '## finished writing in the second fiber'
      end
      Fiber.schedule do
        File.open("./log3.txt", "w"){|f| f.write("ccc") }
        puts '## finished writing in the third fiber'
      end
    end
    thread.join
    puts "It took #{Time.now - t} seconds to run three fibers concurrently."
  end
end
