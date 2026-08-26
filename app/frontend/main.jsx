
import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client"

function App() {
    const [items, setItems] = useState([])
    useEffect(() => {
        fetch("/api/items")
            .then((r) => r.json)
            .then(setItems)
            .catch(() => setItems([{ id: 0, name: "API unreachable" }]));
    }, []);
    return (
        <div style={{ fontFamily: "sans-serif", padding: 40 }}>
            <h1>myapp</h1>
            <ul>{items.map((i) => <li key={i.id}>{i.name}</li>)}</ul>
        </div>
    );
}

createRoot(document.getElementById("root")).render(<App />);