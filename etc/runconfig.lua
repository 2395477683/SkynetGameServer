return {
    cluster={
        node1 ="127.0.0.1:8888",
        node2 ="127.0.0.1:8889",
    },

    agentmgr={node="node1"},

    scene={
        node1={1001,1002},
    },

    node1={
        gateway={
            [1]={port=8000},
            [2]={port=8001},
        },

        login={
            [1]={},
            [2]={},
        },
    },

    node2={
        gateway={
            [1]={port=8010},
            [2]={port=8011},
        },

        login={
            [1]={},
            [2]={},
        },
    },

}