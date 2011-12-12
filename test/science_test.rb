describe "BinRunner" do
  it "help option and command prints help" do
    capture_stdout { start('-h', 'commands') }.should =~ /^commands/
  end

  it "global option takes value with whitespace" do
    View.expects(:render).with {|*args| args[1][:fields] = %w{f1 f2} }
    start('commands', '-f', 'f1, f2')
  end

  describe "render_output" do
    before { Scientist.rendered = false; BinRunner.instance_eval "@options = {}" }

    it "doesn't render when nil, false or true" do
      View.expects(:render).never
      [nil, false, true].each do |e|
        BinRunner.render_output e
      end
    end

    it "doesn't render when rendered with Scientist" do
      Scientist.rendered = true
      View.expects(:render).never
      BinRunner.render_output 'blah'
    end

    it "render with puts when non-string" do
      View.expects(:render).with('dude', {:method => 'puts'})
      BinRunner.render_output 'dude'
    end

    it "renders with inspect when non-array and non-string" do
      [{:a=>true}, :ok].each do |e|
        View.expects(:puts).with(e.inspect)
        BinRunner.render_output e
      end
    end

    it "renders with inspect when Scientist rendering toggled off with :render" do
      Scientist.global_options = {:render=>true}
      View.expects(:puts).with([1,2].inspect)
      BinRunner.render_output [1,2]
      Scientist.global_options = nil
    end

    it "renders with hirb when array" do
      View.expects(:render_object)
      BinRunner.render_output [1,2,3]
    end
  end

end

describe "Manager" do
  describe "option commands without args" do
    before_all {
      reset_boson
      @library = Library.new(:name=>'blah', :commands=>['foo', 'bar'])
      Boson.libraries << @library
      @foo = Command.new(:name=>'foo', :lib=>'blah', :options=>{:fool=>:string}, :args=>'*')
      Boson.commands << @foo
      Boson.commands << Command.new(:name=>'bar', :lib=>'blah', :options=>{:bah=>:string})
    }

    it "are deleted" do
      Scientist.expects(:redefine_command).with(anything, @foo)
      Manager.redefine_commands(@library, @library.commands)
    end

    it "are deleted and printed when verbose" do
      Scientist.expects(:redefine_command).with(anything, @foo)
      @library.instance_eval("@options = {:verbose=>true}")
      capture_stdout { Manager.redefine_commands(@library, @library.commands) } =~ /options.*blah/
    end
  end
end