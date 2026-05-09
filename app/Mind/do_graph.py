from app.Mind.graph import build_graph

g = build_graph()

print(g.get_graph().draw_mermaid())