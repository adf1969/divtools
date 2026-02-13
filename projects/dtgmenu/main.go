package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	appTitle = flag.String("title", "Select an Option", "Title of the menu")
)

var (
	docStyle = lipgloss.NewStyle().Margin(1, 2)
    // Box Style
	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.DoubleBorder()).
			BorderForeground(lipgloss.Color("63")). // Purple-ish
			Padding(0, 1)
)

type item struct {
	tag, title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

type model struct {
	list     list.Model
	choice   string
	quitting bool
    cancelled bool
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc", "q":
			m.quitting = true
            m.cancelled = true
			return m, tea.Quit
		case "enter":
			i, ok := m.list.SelectedItem().(item)
			if ok {
				m.choice = i.tag
			}
			m.quitting = true
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		h, v := boxStyle.GetFrameSize()
		m.list.SetSize(msg.Width-h, msg.Height-v)
	}

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
    // If specifically asked to not quit clear screen, we could just return empty
    if m.choice != "" {
        return "" 
    }
    if m.quitting {
        return ""
    }
    
    // Render the list inside the box
	return boxStyle.Render(m.list.View())
}

func main() {
	flag.Parse()
	args := flag.Args()

	if len(args) == 0 || len(args)%2 != 0 {
		fmt.Println("Usage: dtmenu --title \"Title\" \"tag1\" \"Item 1 Description\" \"tag2\" \"Item 2 Description\"")
		os.Exit(1)
	}

	var items []list.Item
	for i := 0; i < len(args); i += 2 {
		items = append(items, item{
			tag:   args[i],
			title: args[i+1],
			desc:  "", // Currently using single line items, title holds the text
		})
	}

    // Configure the list
    const defaultWidth = 40
    const listHeight = 14
    
    // We use the default delegate but might want to customize for "Tag" visibility if needed
    // For now, standard list
	l := list.New(items, list.NewDefaultDelegate(), defaultWidth, listHeight)
	l.Title = *appTitle
    l.SetShowStatusBar(false)
    l.SetFilteringEnabled(false)
    l.Styles.Title = lipgloss.NewStyle().
            Foreground(lipgloss.Color("#FFF")).
            Background(lipgloss.Color("#005FD7")). // Blue header
            Padding(0, 1)

	m := model{list: l}

	p := tea.NewProgram(m, tea.WithAltScreen()) // Use AltScreen to preserve history

	if finalModel, err := p.Run(); err != nil {
		fmt.Printf("Error running program: %v", err)
		os.Exit(1)
	} else {
        // Assert type
        finalM := finalModel.(model)
		if finalM.choice != "" {
			fmt.Print(finalM.choice) // Print ONLY the tag to stdout
            os.Exit(0)
		} else {
            os.Exit(1) // Cancelled
        }
	}
}
