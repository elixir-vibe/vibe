[
  layers: [
    json_value: [
      "Vibe.Storage.JSON.Value",
      "Vibe.Transport.JSON.Value",
      "Vibe.Tool.Transport.JSON.Value"
    ],
    storage: ["Vibe.Repo", "Vibe.Storage*", "Vibe.Session.Store*"],
    event: ["Vibe.Event", "Vibe.Event.*"],
    session: [
      "Vibe.Session",
      "Vibe.Session.Command*",
      "Vibe.Session.Current",
      "Vibe.Session.Listing",
      "Vibe.Session.Preview",
      "Vibe.Session.Processes",
      "Vibe.Session.PromptLifecycle",
      "Vibe.Session.Registry"
    ],
    command: "Vibe.Command*",
    tool: [
      "Vibe.Tool",
      "Vibe.Tool.AdapterResult",
      "Vibe.Tool.Builtin*",
      "Vibe.Tool.Event",
      "Vibe.Tool.Output*",
      "Vibe.Tool.PluginCall",
      "Vibe.Tool.PluginResult",
      "Vibe.Tool.Result"
    ],
    transport: ["Vibe.Transport*", "Vibe.Remote.Transport*", "Vibe.Tool.Transport*"],
    presentation: "Vibe.Presentation*",
    markdown: ["Vibe.Markdown", "Vibe.MD"],
    surface: [
      "Vibe.UI.Autocomplete*",
      "Vibe.UI.Block*",
      "Vibe.UI.Editor*",
      "Vibe.UI.Error",
      "Vibe.UI.FileAutocomplete",
      "Vibe.UI.Message",
      "Vibe.UI.Notification",
      "Vibe.UI.Reducer",
      "Vibe.UI.Selector",
      "Vibe.UI.State",
      "Vibe.UI.ViewModel"
    ],
    tui: "Vibe.TUI*",
    web: "Vibe.Web*",
    plugin: ["Vibe.Plugin*", "Vibe.Plugins*"]
  ],
  deps: [
    forbidden: [
      {:json_value, :storage},
      {:json_value, :event},
      {:json_value, :session},
      {:json_value, :command},
      {:json_value, :tool},
      {:json_value, :transport},
      {:json_value, :presentation},
      {:json_value, :markdown},
      {:json_value, :surface},
      {:json_value, :tui},
      {:json_value, :web},
      {:json_value, :plugin},
      {:storage, :presentation},
      {:storage, :tui},
      {:storage, :web},
      {:event, :storage},
      {:event, :surface},
      {:event, :presentation},
      {:event, :tool},
      {:event, :plugin},
      {:transport, :storage},
      {:presentation, :storage},
      {:tui, :storage, except_edges: [{"Vibe.TUI.Storybook", "Vibe.Session.Store"}]}
    ]
  ],
  source: [
    forbidden_modules: [
      "Vibe.Actions.*",
      "Vibe.Tools.*",
      "Vibe.ToolOutput",
      "Vibe.ToolDisplay",
      "Vibe.Tool.Presentation",
      "Vibe.Tool.Presentation.*",
      "Vibe.UI.Command",
      "Vibe.UI.Event",
      "Vibe.UI.Event.*",
      "Vibe.UI.Bus",
      "Vibe.UI.SlashCommands",
      "Vibe.UI.SlashCommands.*",
      "Vibe.Storage.Schema.UIEvent",
      "Vibe.Storage.Schema.UIEventFTS",
      "Vibe.Session.Store.Codec",
      "Vibe.Storage.Representation.SessionLog",
      "Vibe.JSON.Encode",
      "Vibe.WebTools",
      "Vibe.WebTools.*",
      "Vibe.Plugins.WebSearch.API"
    ],
    forbidden_files: [
      "lib/vibe/actions/**",
      "lib/vibe/tools/**",
      "lib/vibe/tool/presentation.ex",
      "lib/vibe/tool/presentation/**",
      "lib/vibe/ui/command.ex",
      "lib/vibe/ui/event.ex",
      "lib/vibe/ui/bus.ex",
      "lib/vibe/ui/slash_commands.ex",
      "lib/vibe/ui/slash_commands/**",
      "lib/vibe/storage/schema/ui_event.ex",
      "lib/vibe/storage/schema/ui_event_fts.ex",
      "lib/vibe/session/store/codec.ex",
      "lib/vibe/storage/representation/session_log.ex",
      "lib/vibe/web_tools.ex",
      "lib/vibe/web_tools/**",
      "lib/vibe/json/tuple_encoder.ex",
      "lib/vibe/json/encode.ex",
      "lib/vibe/plugins/web_search/api.ex",
      "lib/vibe/command/markdown.ex",
      "lib/vibe/code/ast/markdown.ex",
      "lib/vibe/image/markdown.ex",
      "lib/vibe/storage/json/presentation_encoders.ex",
      "lib/vibe/storage/json/surface_encoders.ex",
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
      {"Vibe.Files.ImageRef",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.Files.ReadResult",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!",
         "Vibe.Storage.Representation.*"
       ]},
      {"Vibe.UI.Error",
       [
         "Jason.encode",
         "Jason.encode!",
         "Jason.decode",
         "Jason.decode!"
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
      {"Vibe.Storage.*", ["Vibe.Presentation.*", "Vibe.TUI.*", "Vibe.Web.*"]},
      {"Vibe.Remote.*", ["Vibe.UI.*"]},
      {"Vibe.Gateway.*", ["Vibe.UI.*"]},
      {"Vibe.Web.StorageLive", ["Phoenix.HTML.raw"]},
      {"Vibe.*",
       [
         "Vibe.Session.Store.ui_events_path",
         "Vibe.Session.Store.append_ui_event",
         "Vibe.Session.Store.append_ui_events",
         "Vibe.Session.Store.ui_events",
         "Vibe.Session.Store.ui_events_after",
         "Vibe.Plugin.Manager.ui_document"
       ]}
    ]
  ],
  effects: [
    allowed: []
  ],
  boundaries: [
    public: [],
    internal: [
      "Vibe.Storage.Representation.*",
      "Vibe.UI.Reducer.RestoredPayload",
      "Vibe.UI.Reducer.Selector",
      "Vibe.Session.CommandHandler",
      "Vibe.Plugin.Manager.Pipeline"
    ],
    internal_callers: [
      {"Vibe.Storage.Representation.*",
       ["Vibe.Storage.*", "Vibe.Session.Store*", "Jason.Encoder.Vibe.Storage.Representation.*"]},
      {"Vibe.UI.Reducer.RestoredPayload", ["Vibe.UI.Reducer"]},
      {"Vibe.UI.Reducer.Selector", ["Vibe.UI.Reducer"]},
      {"Vibe.Session.CommandHandler", ["Vibe.Session"]},
      {"Vibe.Plugin.Manager.Pipeline", ["Vibe.Plugin.Manager"]}
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
    strict: true,
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
