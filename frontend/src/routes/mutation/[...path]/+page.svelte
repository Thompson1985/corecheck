<script>
  import { onMount } from "svelte";
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { env } from '$env/dynamic/public'
  let selectedFile = '';
  let fileContent = '';
  let mutationData = {};
  let expandedLines = new Set();
  let expanded = new Set(['src', 'src/script', 'src/wallet']);

  const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/bitcoin/bitcoin/master';

  let mutationsMeta = {};
  let mutations = [];
  let countMutations = 0;

  onMount(async () => {
    try {
      const response = await fetch(env.PUBLIC_ENDPOINT + '/mutations/meta');
      mutationsMeta = await response.json();
    } catch (error) {
        console.error("Failed to fetch mutation metadata:", error);
    }

    try {
        const response = await fetch(env.PUBLIC_ENDPOINT + '/mutations');
        mutations = await response.json();
    } catch (error) {
        console.error("Failed to fetch mutations:", error);
    }
      
    function countDiffs(jsonData) {
        return jsonData.reduce((total, file) => {
            return total + Object.values(file.diffs).reduce((sum, diffArray) => sum + diffArray.length, 0);
        }, 0);
    }

    // Subscribe to page store to react to URL changes
    const unsubscribe = page.subscribe(($page) => {
        const pathname = $page.url.pathname;

        if (pathname === '/mutation' || pathname === '/mutation/') {
            selectedFile = null;
            return;
        }

        // Check if we're on a mutation path
        if (pathname.startsWith('/mutation/')) {
            const filePath = pathname.replace('/mutation/', '');

            // Verify the file exists in your structure
            if (fileExists(filePath)) {
                // Only call handleFileSelect if it's different from current selection
                if (selectedFile !== filePath) {
                handleFileSelect(filePath, false); // Don't update URL since we're responding to URL change
                }
            } else {
                // Handle invalid file path - redirect to main mutation page or show error
                console.warn(`File not found: ${filePath}`);
                goto('/mutation', { replaceState: true });
            }
        }
    });

    countMutations = countDiffs(mutations);
    return unsubscribe;
  });

  const files = {
    'src': {
      'wallet': {
        'coinselection.cpp': 'content',
      },
      'script': {
        'interpreter.cpp': 'content'
      },
      'consensus': {
        'tx_verify.cpp': 'content',
        'tx_check.cpp': 'content',
        'merkle.cpp': 'content'
      },
      'util': {
        'asmap.cpp': 'content'
      },
      'pow.cpp': 'content',
      'addrman.cpp': 'content'
    },
  };

function toggleLine(lineNumber) {
  expandedLines = new Set(expandedLines);
  if (expandedLines.has(lineNumber)) {
    expandedLines.delete(lineNumber);
  } else {
    expandedLines.add(lineNumber);
  }
}

function onFileClick(file) {
  handleFileSelect(file, true); // This will update the URL
}

function fileExists(filePath) {
  const parts = filePath.split('/');
  let current = files;

  for (const part of parts) {
    if (current && typeof current === 'object' && part in current) {
      current = current[part];
    } else {
      return false;
    }
  }
  return true;
}

// Helper function to get all valid file paths from your structure
function getAllFilePaths(obj = files, currentPath = '') {
  let paths = [];

  for (const [key, value] of Object.entries(obj)) {
    const newPath = currentPath ? `${currentPath}/${key}` : key;

    if (typeof value === 'object' && value !== null) {
      paths = paths.concat(getAllFilePaths(value, newPath));
    } else {
      paths.push(newPath);
    }
  }

  return paths;
}

async function handleFileSelect(file, updateUrl = true) {
    selectedFile = file;

    // Update URL if requested (default true)
    if (updateUrl) {
        goto(`/mutation/${file}`, { replaceState: false });
    }

    try {
        const selected_mutations = mutations.filter(val => val.filename.includes(file));
        if(selected_mutations.length > 0 && 'diffs' in selected_mutations[0]) {
        mutationData = selected_mutations[0].diffs || {};
        } else {
        mutationData = {};
        }

        // Fetch file content from GitHub raw URL
        const githubPath = `${GITHUB_RAW_BASE}/${file}`;
        const contentResp = await fetch(githubPath);
        if (!contentResp.ok) {
        throw new Error(`Failed to fetch file: ${contentResp.status}`);
        }
        fileContent = await contentResp.text();
    } catch (error) {
        console.error('Error:', error);
        fileContent = `Error loading content: ${error.message}`;
        mutationData = {};
    }
    }


  function toggleDir(path) {
    expanded = new Set(expanded);
    if (expanded.has(path)) {
      expanded.delete(path);
    } else {
      expanded.add(path);
    }
  }


  function renderTree(tree, path = '') {
    return Object.entries(tree).map(([name, value]) => {
      const currentPath = path ? `${path}/${name}` : name;
      if (typeof value === 'string') {
        return {
          type: 'file',
          name,
          path: currentPath
        };
      } else {
        return {
          type: 'directory',
          name,
          path: currentPath,
          children: renderTree(value, currentPath)
        };
      }
    });
  }

  $: treeData = renderTree(files);
</script>

<div class="page-wrapper">
  <!-- File Tree -->
  <div class="file-tree">
    <h2 class="text-xl font-bold mb-4">Files</h2>
    {#each treeData as item}
      {#if item.type === 'file'}
        <div
          class="pl-6 py-1 cursor-pointer hover:bg-gray-200 {selectedFile === item.path ? 'bg-blue-100' : ''}"
          on:click={() => handleFileSelect(item.path)}
        >
          📄 {item.name}
        </div>
      {:else}
        <div>
          <div
            class="py-1 cursor-pointer hover:bg-gray-200 flex items-center"
            on:click={() => toggleDir(item.path)}
          >
            <span class="mr-2">{expanded.has(item.path) ? '📂' : '📁'}</span>
            {item.name}
          </div>
          {#if expanded.has(item.path)}
            <div class="directory">
              {#each item.children as child}
                {#if child.type === 'file'}
                  <div
                    class="pl-6 py-1 cursor-pointer hover:bg-gray-200 {selectedFile === child.path ? 'bg-blue-100' : ''}"
                    on:click={() => handleFileSelect(child.path)}
                  >
                    📄 {child.name}
                  </div>
                {:else}
                  <div>
                    <div
                      class="py-1 cursor-pointer hover:bg-gray-200 flex items-center"
                      on:click={() => toggleDir(child.path)}
                    >
                      <span class="mr-2">{expanded.has(child.path) ? '📂' : '📁'}</span>
                      {child.name}
                    </div>
                    {#if expanded.has(child.path)}
                      <div class="directory">
                        {#each child.children as grandChild}
                          <div
                            class="pl-6 py-1 cursor-pointer hover:bg-gray-200 {selectedFile === grandChild.path ? 'bg-blue-100' : ''}"
                            on:click={() => handleFileSelect(grandChild.path)}
                          >
                            📄 {grandChild.name}
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/if}
              {/each}
            </div>
          {/if}
        </div>
      {/if}
    {/each}
  </div>

  {#if !selectedFile}
    <div class="content">
      <div class="">
        <div class="shadow document" style="">
          <div class="heading" style="">
            <h2 class="">Mutation Testing</h2>
          </div>

          <div class="main-content">
            <div>
              <span>Last Ran: {new Date(mutationsMeta.created_at)}</span>
            </div>
            <div>
              <span>For Commit: {mutationsMeta.commit}</span>
            </div>
            <div>
              Total unkilled mutants: {countMutations}
            </div>
            <div>
              <a href="{env.PUBLIC_ENDPOINT}/mutations">Raw mutation-core output</a>
            </div>
            <div>
              <br><br>
              To view the mutants, select a file from the left.
            </div>
            <div>
              <br><br>
              To see the exact mutation-core commands that corecheck.dev ran, checkout the <a href="https://raw.githubusercontent.com/corecheck/corecheck/refs/heads/master/workers/mutation-worker/entrypoint.sh">entrypoint.sh</a> file for the mutation worker.
            </div>
          </div>
        </div>
      </div>
    </div>


  {/if}
  <!-- Content View -->
  {#if selectedFile}
    <div class="content">
      <div class="">
        <div class="shadow document" style="">
          <div class="heading" style="">
            <h2 class=""><a on:click={() => goto('/mutation', { replaceState: true })} style="text-decoration: underline;">Mutations</a> -> {selectedFile}</h2>
          </div>

          <div class="main-content code-container">
            <div class="code-scroll-wrapper">
              {#each fileContent.split('\n') as line, index}
                {@const lineNumber = index + 1}
                {@const hasMutants = mutationData[lineNumber]}
                {@const lineColor = hasMutants ? 'text-red-600' : 'text-green-600'}

                <div class="">
                  <div
                    style=""
                    class="line-wrapper {hasMutants ? 'red' : ''}"
                    on:click={() => hasMutants && toggleLine(lineNumber)}
                  >
                    <div class="lineno" style="">
                      {lineNumber}
                    </div>
                    <div class="line">
                      {#if hasMutants}
                        <span class="chevron">
                          {expandedLines.has(lineNumber) ? '▼' : '▶'}
                        </span>
                      {/if}
                      <span><pre>{line}</pre></span>
                    </div>
                  </div>

                  {#if expandedLines.has(lineNumber) && hasMutants}
                    <div class="mutant-container">
                      {#each hasMutants as mutant}
                        <div class="" style="margin-bottom: 1rem;">
                          <div class="mutant-title">
                            Mutant #{mutant.id} - {mutant.status}
                          </div>
                          <div class="mutant-content">
                            <pre>{mutant.diff}</pre>
                          </div>
                        </div>
                      {/each}
                    </div>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .file-tree {
    position: fixed;
    width: 300px;
    height: 100vh;
    overflow-y: auto;
    background: #f8f9fa;
    padding: 1rem;
    border-right: 1px solid #dee2e6;
    z-index: 10;
  }

  @media (max-width: 768px) {
    .file-tree {
      width: 100%;
      height: auto;
      max-height: 50vh;
      position: relative;
      border-right: none;
      border-bottom: 1px solid #dee2e6;
    }

    .content {
      margin-left: 0 !important;
    }
  }

  .content {
    margin-left: 300px;
    padding: 1rem;
    background-color: white;
  }
  .content a {
    cursor: pointer;
  }

  .directory {
    padding-left: 1.5rem;
  }
  .shadow {
    --tw-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1),0 4px 6px -2px rgba(0, 0, 0, 0.05);
    box-shadow: 0 0 #0000,0 0 #0000, 0 0 #0000,0 0 #0000,var(--tw-shadow);
  }
  .heading {
    padding: 1rem;
    border-bottom-width: 1px;
    border-style: solid;
    border-color: rgba(229, 231, 235, 1);
  }
  .document {
    max-width: 100%;
    margin-right: auto;
    margin-left: auto;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  }
  .main-content {
    padding: 1rem;
    background-color: rgba(249,250,251,1);
    min-height: 100vh;
  }
  .line {
    color: rgba(5,150,105,1);
    flex: 1 1 0%;
    display: flex;
    white-space: nowrap;
  }

  /* Container for the code with horizontal scrollbar */
  .code-container {
    overflow-x: auto;
    max-width: 100%;
  }

  .code-scroll-wrapper {
    min-width: min-content;
    white-space: nowrap;
  }

  .code-container::-webkit-scrollbar {
    height: 8px;
  }

  .code-container::-webkit-scrollbar-track {
    background: #edf2f7;
  }

  .code-container::-webkit-scrollbar-thumb {
    background-color: #cbd5e0;
    border-radius: 4px;
  }

  .lineno {
    color: rgba(107,114,128,1);
    width: 3rem;
    flex-shrink: 0;
  }
  .line-wrapper {
    display: flex;
    align-items: flex-start;
    width: 100%;
  }
  .chevron {
    margin-right: 0.5rem;
    flex-shrink: 0;
  }
  .red {
    background-color: rgba(254,226,226,1);
  }
  .mutant-container {
    padding-left: 1rem;
    border-style: solid;
    border-left-width: 2px;
    border-color: rgba(229,231,235,1);
    margin-left: 3rem;
    margin-bottom: .5rem;
    margin-top: .5rem;
    width: calc(100% - 3rem);
  }
  .mutant-title {
    color: rgba(75,85,99,1);
  }
  .mutant-content {
    font-size: .875rem;
    line-height: 1.25rem;
    padding: 0.5rem;
    background-color: rgba(243,244,246,1);
    overflow: hidden;
  }

  @media (max-width: 480px) {
    .lineno {
      width: 2rem;
    }

    .mutant-container {
      margin-left: 2rem;
      width: calc(100% - 2rem);
    }
  }
</style>
