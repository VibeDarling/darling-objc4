# Capture regression: capacity never depends on mutable membership.
require 'tmpdir'
require 'open3'
source = File.read(File.join(ARGV.fetch(0, File.expand_path('..', __dir__)), 'runtime/objc-runtime-new.h'))
code = source[/template <typename List>\nstruct relative_list_entry_t.*?(?=\n#endif)/m]
abort 'relative list templates missing' unless code
Dir.mktmpdir('objc-relative-snapshot-') do |dir|
  File.write("#{dir}/probe.cpp", <<~CPP)
    #include <stdint.h>
    #include <initializer_list>
    #include <stdlib.h>
    #include <assert.h>
    static bool secondLoaded;
    static bool firstLoaded = true;
    static unsigned queries;
    bool relativeMetadataImageIsLoaded(uint16_t index) {
      ++queries;
      return index == 0 ? firstLoaded : secondLoaded;
    }
    #{code}
    int main() {
      alignas(8) unsigned char storage[24] = {};
      auto lists = reinterpret_cast<relative_list_list_t<int> *>(storage);
      lists->entsize = 8; lists->count = 2;
      lists->entries[0].raw = 0;
      lists->entries[1].raw = 1;
      for (bool initial : {false, true}) {
        for (bool after : {false, true}) {
          secondLoaded = initial; queries = 0;
          auto capacity = lists->listCapacity();
          assert(capacity == 2 && queries == 0);
          auto output = static_cast<int **>(malloc(capacity * sizeof(int *)));
          secondLoaded = after;
          auto copied = lists->copyLoadedLists(output);
          assert(copied == (after ? 2U : 1U) && queries == 2);
          assert(output[0] == lists->entries[0].list());
          if (after) assert(output[1] == lists->entries[1].list());
          free(output);
        }
      }
      firstLoaded = secondLoaded = false; queries = 0;
      int *sentinel[2] = {reinterpret_cast<int *>(1), reinterpret_cast<int *>(2)};
      assert(lists->copyLoadedLists(sentinel) == 0 && queries == 2);
      assert(sentinel[0] == reinterpret_cast<int *>(1));
      assert(sentinel[1] == reinterpret_cast<int *>(2));
      lists->entsize = 0; queries = 0;
      assert(lists->listCapacity() == 0);
      assert(lists->copyLoadedLists(nullptr) == 0 && queries == 0);
      lists->entsize = 8; lists->count = 0;
      assert(lists->listCapacity() == 0);
      assert(lists->copyLoadedLists(nullptr) == 0 && queries == 0);
    }
  CPP
  out, status = Open3.capture2e('clang++', '-std=c++11', '-fsanitize=address,undefined',
                               "#{dir}/probe.cpp", '-o', "#{dir}/probe")
  abort out unless status.success?
  out, status = Open3.capture2e("#{dir}/probe")
  abort out unless status.success?
  puts 'PASS: growth, shrinkage, stable membership, invalid stride and empty capture'
end
