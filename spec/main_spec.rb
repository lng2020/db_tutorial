describe 'database' do
  def run_script(commands)
    raw_output = nil
    IO.popen("./db", "r+") do |pipe|
      commands.each do |command|
        begin 
          pipe.puts command
        rescue Errno::EPIPE
          break
        end
      end

      pipe.close_write

      raw_output = pipe.gets(nil)
    end
    raw_output.split("\n")
  end

  it "inserts and retrieves a row" do
    result = run_script([
      "insert 1 user1 person1@example.com",
      "select",
      ".exit",
    ])
    expect(result).to match_array([
      "db > Executed.",
      "db > (1, user1, person1@example.com)",
      "Executed.",
      "db > ",
    ])
  end

  it 'prints error message when table is full' do
    script = (1..1401).map do |i|
      "insert #{i} user#{i} person#{i}@example.com"
    end
    script << ".exit"
    result = run_script(script)
    expect(result.last(2)).to match_array([
      "db > Executed.",
      "db > Need to implement updating parent after split.",
    ])
  end

  it 'allows inserting strings that are the maximum length' do
    long_username = "a"*32
    long_email = "a"*255
    script = [
      "insert 1 #{long_username} #{long_email}",
      "select",
      ".exit",
    ]
    result = run_script(script)
    expect(result).to match_array([
      "db > Executed.",
      "db > (1, #{long_username}, #{long_email})",
      "Executed.",
      "db > ",
    ])
  end

  it 'prints error message if strings are too long' do
    long_username = "a"*33
    long_email = "a"*256
    script = [
      "insert 1 #{long_username} #{long_email}",
      "select",
      ".exit",
    ]
    result = run_script(script)
    expect(result).to match_array([
      "db > String is too long.",
      "db > Executed.",
      "db > ",
    ])
  end

  it 'prints an error message if id is negative' do
    script = [
      "insert -1 cstack foo@bar.com",
      "select",
      ".exit",
    ]
    result = run_script(script)
    expect(result).to match_array([
      "db > ID must be positive.",
      "db > Executed.",
      "db > ",
    ])
  end

  it 'keeps data after closing connection' do
    result1 = run_script([
      "insert 1 user1 person1@example.com",
      ".exit",
    ])
    expect(result).to match_array([
      "db > Executed.",
      "db > ",
    ])
    result2 = run_script([
      "select",
      ".exit",
    ])
    expect(result2).to match_array([
      "db > (1, user1, person1@example.com",
      "Executed.",
      "db > ",
    ])
  end 

  it 'prints constants' do
    script = [
      ".constants",
      ".exit",
    ]
    result = run_script(script)
    expect(result).to match_array([
      "db > Constants:",
      "ROW_SIZE: 293",
      "COMMON_NODE_HEADER_SIZE: 6",
      "LEAF_NODE_HEADER_SIZE: 14",
      "LEAF_NODE_CELL_SIZE: 297",
      "LEAF_NODE_SPACE_FOR_CELLS: 4086",
      "LEAF_NODE_MAX_CELLS: 13",
      "db > ",
    ])
  end 
  
  it 'allows printing out the structure of a one-node btree' do
    script = [3, 1, 2].map do |i|
      "insert #{i} user#{i} person#{i}@example"
    end
    script << ".btree"
    script << ".exit"
    result = run_script(script)
    expect(result).to match_array([
      "db > Executed.",
      "db > Executed.",
      "db > Executed.",
      "db > Tree:",
      "- leaf (size 3)",
      "  - 0",
      "  - 1",
      "  - 2",
      "db > ",
    ])
  end

  it 'prints an error message if there is a duplicate id' do
    script = [
      "insert 1 user1 person1@example.com",
      "insert 1 user1 person1@example.com",
      "select",
      ".exit",
    ]
    result = run_script(script)
    expect(result).to match_array([
      "db > Executed.",
      "db > Error: Duplicate key.",
      "db > (1, user1, person1@example.com)",
      "db > ",
    ])
  end

  it 'allows printing out the structure of a 3-leaf-node btree' do
    script = (1..14).map do |i|
      "insert #{i} user#{i} person#{i}@example"
    end
    script << ".btree"
    script << "insert 15 user15 person15@example"
    script << ".exit"
    result = run_script(script)

    expect(result[14...(result.length)]).to match_array([
      "db > Tree:",
      "- internal (size 1)",
      "  - leaf (size 7)",
      "    - 1",
      "    - 2",
      "    - 3",
      "    - 4",
      "    - 5",
      "    - 6",
      "    - 7",
      " - key 7",
      "- internal (size 2)",
      "  - leaf (size 7)",
      "    - 8",
      "    - 9",
      "    - 10",
      "    - 11",
      "    - 12",
      "    - 13",
      "    - 14",
      "db > Need to implement updating parent after split.",
    ])
  end

  it 'prints all rows in a multi-level tree' do
    script = (1..15).map do |i|
      "insert #{i} user#{i} person#{i}@example"
    end
    script << "select"
    script << ".exit"
    result = run_script(script)
    expect(result[15...(result.length)]).to match_array([
      "db > (1, user1, person1@example)",
      "(2, user2, person2@example)",
      "(3, user3, person3@example)",
      "(4, user4, person4@example)",
      "(5, user5, person5@example)",
      "(6, user6, person6@example)",
      "(7, user7, person7@example)",
      "(8, user8, person8@example)",
      "(9, user9, person9@example)",
      "(10, user10, person10@example)",
      "(11, user11, person11@example)",
      "(12, user12, person12@example)",
      "(13, user13, person13@example)",
      "(14, user14, person14@example)",
      "(15, user15, person15@example)",
      "Executed.",
      "db > ",
    ])
  end

  it 'allows printing out the structure of a 4-leaf-node btree' do
    script = [
      "insert 18 user18 person18@example",
      "insert 7 user7 person7@example",
      "insert 3 user3 person3@example",
      "insert 11 user11 person11@example",
      "insert 1 user1 person1@example",
      "insert 5 user5 person5@example",
      "insert 19 user19 person19@example",
      "insert 4 user4 person4@example",
      "insert 14 user14 person14@example",
      "insert 15 user15 person15@example",
      "insert 16 user16 person16@example",
      "insert 17 user17 person17@example",
      "insert 6 user6 person6@example",
      "insert 8 user8 person8@example",
      "insert 9 user9 person9@example",
      "insert 10 user10 person10@example",
      "insert 2 user2 person2@example",
      "insert 12 user12 person12@example",
      "insert 13 user13 person13@example",
      ".btree",
      ".exit",
    ]
    result = run_script(script)
    expect(result[20...(result.length)]).to match_array([
      "db > Tree:",
      "- internal (size 3)",
      "  - leaf (size 7)",
      "    - 1",
      "    - 2",
      "    - 3",
      "    - 4",
      "    - 5",
      "    - 6",
      "    - 7",
      "   - key 7",
      "  - leaf (size 7)",
      "    - 8",
      "    - 9",
      "    - 10",
      "    - 11",
      "    - 12",
      "    - 13",
      "    - 14",
      "   - key 14",
      "  - leaf (size 2)",
      "    - 15",
      "   - key 15",
      "  - leaf (size 2)",
      "    - 16",
  end
end