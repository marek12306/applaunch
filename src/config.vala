namespace Config {
    public const bool START_HIDDEN = true;

    public const bool SCROLL_BARS = true;
    public const int ICON_SIZE = 64;
    public const int ITEM_SIZE = 130;
    public const int APP_MARGIN = 4;
    public const uint ITEM_SPACING = 16;
    public const int ITEMS_PER_ROW = 6;


    public const bool DOCK_ENABLED = true;
    public const int MAX_DOCK_ITEMS = 8;

    public const string css_data = """
        window, window.background {
            background: rgba(30, 30, 30, 0.9);
            backdrop-filter: blur(100px);
        }
        
        flowboxchild {
            border-radius: 8px;
            padding: 0;
            margin: 0;
            background: transparent;
            border: 1px solid transparent; 
            transition: background 0.2s ease-in-out;
        }
        
        flowboxchild:hover {
            background: rgba(255, 255, 255, 0.1);
        }
        
        flowboxchild:selected {
            background: rgba(255, 255, 255, 0.2);
            border-color: rgba(255, 255, 255, 0.4);
        }

        scrolledwindow overshoot,
        scrolledwindow undershoot {
            background: none;
            box-shadow: none;
        }
        
        popover button {
            margin: 4px;
            border-radius: 6px;
        }

        /* --- STYL DOCKA --- */
        window.dock-window, window.dock-window.background {
            background: transparent;
            backdrop-filter: none;
            box-shadow: none;
        }

        .dock-container {
            background: alpha(@window_bg_color, 0.85);
            border-radius: 20px;
            border: 1px solid alpha(@window_fg_color, 0.1);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            padding: 6px;
        }

        .dock-btn {
            background: transparent;
            padding: 6px;
            border-radius: 16px;
            transition: background 0.2s ease-in-out;
        }

        .dock-btn:hover {
            background: rgba(255, 255, 255, 0.15);
        }

        /* --- DRAG & DROP: USUNIĘCIE NATYWNYCH RAMEK --- */
        
        /* Czyste i poprawne składniowo wyłączenie cieni i obramowań */
        .no-drop-highlight:drop(active),
        .no-drop-highlight *:drop(active) {
            box-shadow: none;
            outline-style: none;
            border-style: none;
            background-color: transparent;
        }

        /* --- STYL NASZEGO WSKAŹNIKA UPUSZCZENIA --- */
        .drop-indicator {
            background-color: #3584e4;
            border-radius: 4px;
        }

        .invisible-trigger { 
            background: transparent; 
        }

        .dock-indicator-box {
            min-height: 4px;
            margin-top: 2px;
        }

        .dock-dot {
            background: rgba(255, 255, 255, 0.85);
            border-radius: 50%;
            min-width: 4px;
            min-height: 4px;
            margin: 0 1px;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
        }

        .dock-line {
            background: rgba(255, 255, 255, 0.85);
            border-radius: 2px;
            min-width: 16px;
            min-height: 4px;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
        }

        separator.dock-separator {
            background: rgba(255, 255, 255, 0.15);
            min-width: 1px;
            margin-left: 4px;
            margin-right: 4px;
        }
    """;
}