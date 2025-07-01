/*
 * Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.ai.plugin;

import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Optional;

/**
 * Analyzes a Ballerina module init function.
 */
class GenerateFunctionAnalysisTask implements AnalysisTask<SyntaxNodeAnalysisContext> {
    private static final String GENERATE_METHOD_NAME = "generate";

    @Override
    public void perform(SyntaxNodeAnalysisContext context) {
        Optional<Symbol> symbolOpt = context.semanticModel().symbol(context.node());
        symbolOpt.ifPresent(symbol -> {
            if (symbol.kind() != SymbolKind.METHOD) {
                return;
            }
        });
    }
}