module StockSolutionsHelper
  def stock_solution_component_badge(component)
    content_tag :span, class: "badge bg-light text-dark" do
      "#{component.chemical.name}: #{component.display_amount}"
    end
  end

  def stock_solution_usage_status(stock_solution)
    count = stock_solution.used_in_wells_count
    if count > 0
      content_tag :span, class: "badge bg-success" do
        "Used in #{pluralize(count, 'well')}"
      end
    else
      content_tag :span, class: "badge bg-secondary" do
        "Not used"
      end
    end
  end

  def stock_solution_delete_button(stock_solution)
    if stock_solution.can_be_deleted?
      link_to "Delete", stock_solution_path(stock_solution),
              method: :delete,
              confirm: "Are you sure you want to delete this stock solution?",
              class: "btn btn-outline-danger btn-sm"
    else
      content_tag :span, class: "btn btn-outline-danger btn-sm disabled" do
        "Cannot delete (in use)"
      end
    end
  end

  def format_components_summary(stock_solution, max_length = 100)
    summary = stock_solution.component_summary
    if summary.length > max_length
      truncate(summary, length: max_length)
    else
      summary
    end
  end
end
