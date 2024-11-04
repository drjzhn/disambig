CREATE TABLE edges (
    id1 INTEGER,
    id2 INTEGER
);

-- loads a test table that contains three patients with different subgraph shapes
-- patient 1 has a K3 clique [2,4,5] with a path [2,1,3]
-- patient 2 is a simple node pair [6,7]
-- patient 3 is a star network centred on [10]
INSERT INTO edges VALUES
    (1, 2), -- patient 1
    (2, 5), -- patient 1
    (3, 1), -- patient 1
    (4, 2), -- patient 1
    (5, 4), -- patient 1
    (6, 7), -- patient 2
    (7, 6), -- patient 2
    (8, 10), -- patient 3
    (9, 10), -- patient 3
    (10, 8), -- patient 3
    (11, 10), -- patient 3
    (12, 10); -- patient 3
    
SELECT * FROM edges;

-- tests the identification of the lowest patient id in each subgraph as the 'anchor'
-- logic as follows:
-- for all nodes in a subgraph, there will always be one node of 'least value'
-- nodes in subgraph X will not interact with nodes outside of subgraph X
-- therefore, by exclude all nodes in a subgraph that have a smaller value in a pair
-- DOES NOT WORK FOR STAR GRAPHS!
WITH edges_bidirectional AS (
    SELECT id1, id2 FROM edges
    UNION
    SELECT id2 as id1, id1 as id2 FROM edges
)
SELECT DISTINCT 
    id1 as anchor
FROM edges_bidirectional
WHERE id1 NOT IN (
    SELECT DISTINCT id2 
    FROM edges_bidirectional 
    WHERE id2 > id1
);

-- recursive graph traversal to identify subgraphs
WITH RECURSIVE 
edges_bidirectional AS (
    SELECT id1, id2 FROM edges
    UNION
    SELECT id2 as id1, id1 as id2 FROM edges
),
connected AS (
    -- anchor
    SELECT DISTINCT 
        id1 as node_id,
        id1 as subgraph_id -- take the anchor as the id for each subgraph
    FROM edges_bidirectional
    WHERE id1 NOT IN (
        SELECT DISTINCT id2 
        FROM edges_bidirectional 
        WHERE id2 > id1
    )
    UNION
    -- joins onto bidirectional graph to traverse
    -- NOT IN excludes nodes we have already seen
    -- new nodes inherit subgraph_id of the node that was joined on
    SELECT DISTINCT
        e.id2 as node_id,
        c.subgraph_id
    FROM edges_bidirectional e
    INNER JOIN connected c ON e.id1 = c.node_id
    WHERE e.id2 NOT IN (SELECT node_id FROM connected)
),
-- star shaped subgraphs may have multiple anchors
-- however, traversal should include all possibly connected nodes
-- we can dedupe subgraphs on agg of node_ids for each subgraph_id
grouped_subgraphs AS (
    SELECT 
        subgraph_id,
        array_agg(node_id ORDER BY node_id) as member_ids
    FROM connected
    GROUP BY subgraph_id
),
deduped_subgraphs AS (
    SELECT 
        member_ids,
        MIN(subgraph_id) as canonical_subgraph_id
    FROM grouped_subgraphs
    GROUP BY member_ids
)
-- final result from deduped 
SELECT 
    canonical_subgraph_id as subgraph_id,
    member_ids,
    array_length(member_ids) as subgraph_size
FROM deduped_subgraphs
ORDER BY canonical_subgraph_id;
