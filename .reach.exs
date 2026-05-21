[
  layers: [],
  deps: [forbidden: []],
  source: [
    forbidden_modules: [
      "Vibe.Actions.*",
      "Vibe.Tools.*",
      "Vibe.ToolOutput",
      "Vibe.ToolDisplay",
      "Vibe.Tool.Presentation",
      "Vibe.Tool.Presentation.*",
      "Vibe.UI.Event",
      "Vibe.UI.Event.*",
      "Vibe.UI.Bus",
      "Vibe.Session.Store.Codec",
      "Vibe.Storage.Representation.SessionLog",
      "Vibe.WebTools",
      "Vibe.WebTools.*",
      "Vibe.Plugins.WebSearch.API"
    ],
    forbidden_files: [
      "lib/vibe/actions/**",
      "lib/vibe/tools/**",
      "lib/vibe/tool/presentation.ex",
      "lib/vibe/tool/presentation/**",
      "lib/vibe/ui/event.ex",
      "lib/vibe/ui/bus.ex",
      "lib/vibe/session/store/codec.ex",
      "lib/vibe/storage/representation/session_log.ex",
      "lib/vibe/web_tools.ex",
      "lib/vibe/web_tools/**",
      "lib/vibe/plugins/web_search/api.ex",
      "lib/vibe/command/markdown.ex",
      "lib/vibe/code/ast/markdown.ex",
      "lib/vibe/image/markdown.ex",
      "lib/vibe/storage/search/markdown.ex",
      "lib/vibe/subagents/markdown.ex",
      "lib/vibe/tool/markdown.ex",
      "lib/vibe/plugins/web_search/markdown.ex"
    ]
  ],
  calls: [
    forbidden: [
      {"Vibe.SystemAlarms.*",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.Tool.*",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.Trajectory",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.Model.Content.*",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.Image",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.UI.*",
       [
         "Vibe.Storage.Representation.*",
         "Vibe.Storage.Persistable.*",
         "Vibe.Storage.Restorable.*"
       ]},
      {"Vibe.Web.*",
       [
         "Vibe.Storage.Representation.*",
         "Vibe.Storage.Persistable.*",
         "Vibe.Storage.Restorable.*"
       ]},
      {"Vibe.TUI.*",
       [
         "Vibe.Storage.Representation.*",
         "Vibe.Storage.Persistable.*",
         "Vibe.Storage.Restorable.*"
       ]},
      {"Vibe.Storage.*", ["Vibe.Presentation.*", "Vibe.TUI.*", "Vibe.Web.*"]}
    ]
  ],
  effects: [
    allowed: []
  ],
  boundaries: [
    public: [],
    internal: [
      "Vibe.Storage.Representation.*"
    ],
    internal_callers: [
      {"Vibe.Storage.Representation.*", ["Vibe.Storage.*", "Vibe.Session.Store*"]}
    ]
  ],
  risk: [
    changed: [
      many_direct_callers: 5,
      wide_transitive_callers: 10,
      branch_heavy: 8,
      high_risk_reason_count: 3
    ]
  ],
  candidates: [
    thresholds: [
      mixed_effect_count: 2,
      branchy_function_branches: 8,
      high_risk_direct_callers: 4
    ],
    limits: [
      per_kind: 20,
      representative_calls: 10,
      representative_calls_per_edge: 3
    ]
  ],
  clone_analysis: [
    provider: :ex_dna,
    min_mass: 30,
    min_similarity: 1.0,
    max_clones: 50
  ],
  smells: [
    fixed_shape_map: [
      min_keys: 3,
      min_occurrences: 3,
      evidence_limit: 10
    ],
    behaviour_candidate: [
      min_modules: 3,
      min_callbacks: 3,
      module_display_limit: 8,
      callback_display_limit: 8
    ]
  ],
  tests: [
    hints: [
      {"lib/vibe/storage/representation/**", ["test/vibe/storage/representation"]},
      {"lib/vibe/presentation/**",
       ["test/vibe/presentation", "test/vibe/tui/presentation", "test/vibe/web/presentation"]},
      {"lib/vibe/event/**", ["test/vibe/event"]},
      {"lib/vibe/plugins/web_search/**",
       ["test/vibe/plugins/web_search_test.exs", "test/vibe/plugins/web_search"]}
    ]
  ]
]
